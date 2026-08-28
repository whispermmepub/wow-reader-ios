import Foundation
import ZIPFoundation

struct EPUBChapter: Identifiable, Hashable {
    let id: String
    let title: String
    let url: URL
}

struct EPUBPackage {
    let title: String
    let rootURL: URL
    let chapters: [EPUBChapter]
}

enum EPUBDocumentError: Error {
    case invalidContainer
    case missingPackage
    case emptySpine
}

enum EPUBDocument {
    static func prepare(at epubURL: URL) throws -> EPUBPackage {
        let destination = extractionDirectory(for: epubURL)
        let fm = FileManager.default
        if !fm.fileExists(atPath: destination.path) {
            try fm.createDirectory(at: destination, withIntermediateDirectories: true)
            do {
                try fm.unzipItem(at: epubURL, to: destination)
            } catch {
                try? fm.removeItem(at: destination)
                throw error
            }
        }

        let containerURL = destination.appendingPathComponent("META-INF/container.xml")
        guard let packagePath = try parseContainer(containerURL), !packagePath.isEmpty else {
            throw EPUBDocumentError.invalidContainer
        }

        let packageURL = destination.appendingPathComponent(packagePath)
        guard fm.fileExists(atPath: packageURL.path) else {
            throw EPUBDocumentError.missingPackage
        }

        let parsed = try parsePackage(packageURL)
        let packageDirectory = packageURL.deletingLastPathComponent()
        var chapters: [EPUBChapter] = []
        for (index, idref) in parsed.spine.enumerated() {
            guard let item = parsed.manifest[idref] else { continue }
            let href = item.href.removingPercentEncoding ?? item.href
            let fileURL = packageDirectory.appendingPathComponent(href)
            guard fm.fileExists(atPath: fileURL.path) else { continue }
            let title = htmlHeading(at: fileURL) ?? "Chapter \(index + 1)"
            chapters.append(EPUBChapter(id: idref, title: title, url: fileURL))
        }
        guard !chapters.isEmpty else { throw EPUBDocumentError.emptySpine }

        let fallback = epubURL.deletingPathExtension().lastPathComponent
        let title = parsed.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return EPUBPackage(
            title: (title?.isEmpty == false ? title! : fallback),
            rootURL: destination,
            chapters: chapters
        )
    }

    static func metadataTitle(at epubURL: URL) throws -> String {
        try prepare(at: epubURL).title
    }

    private struct ManifestItem {
        let href: String
    }

    private struct PackageData {
        var title: String?
        var manifest: [String: ManifestItem]
        var spine: [String]
    }

    private static func extractionDirectory(for url: URL) -> URL {
        let fm = FileManager.default
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let attrs = try? fm.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        let modified = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let raw = "\(url.lastPathComponent)-\(size)-\(Int(modified))"
        let safe = raw.replacingOccurrences(of: "[^A-Za-z0-9._-]", with: "_", options: .regularExpression)
        return caches
            .appendingPathComponent("WoWReader", isDirectory: true)
            .appendingPathComponent("EPUB", isDirectory: true)
            .appendingPathComponent(safe, isDirectory: true)
    }

    private static func parseContainer(_ url: URL) throws -> String? {
        let parser = XMLParser(contentsOf: url)
        let delegate = ContainerParser()
        parser?.delegate = delegate
        guard parser?.parse() == true else { return nil }
        return delegate.fullPath
    }

    private static func parsePackage(_ url: URL) throws -> PackageData {
        guard let parser = XMLParser(contentsOf: url) else { throw EPUBDocumentError.missingPackage }
        let delegate = PackageParser()
        parser.delegate = delegate
        guard parser.parse() else { throw parser.parserError ?? EPUBDocumentError.missingPackage }
        return PackageData(title: delegate.title, manifest: delegate.manifest, spine: delegate.spine)
    }

    private static func htmlHeading(at url: URL) -> String? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let patterns = [
            #"(?is)<h[1-3][^>]*>(.*?)</h[1-3]>"#,
            #"(?is)<title[^>]*>(.*?)</title>"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range(at: 1), in: text) else { continue }
            let raw = String(text[range])
            let stripped = raw.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !stripped.isEmpty && stripped.count < 160 { return stripped }
        }
        return nil
    }

    private final class ContainerParser: NSObject, XMLParserDelegate {
        var fullPath: String?
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            if elementName.lowercased().hasSuffix("rootfile") {
                fullPath = attributeDict["full-path"]
            }
        }
    }

    private final class PackageParser: NSObject, XMLParserDelegate {
        var title: String?
        var manifest: [String: ManifestItem] = [:]
        var spine: [String] = []
        private var collectingTitle = false
        private var titleBuffer = ""

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            let name = elementName.lowercased()
            if name.hasSuffix("title") {
                collectingTitle = true
                titleBuffer = ""
            } else if name.hasSuffix("item"), let id = attributeDict["id"], let href = attributeDict["href"] {
                manifest[id] = ManifestItem(href: href)
            } else if name.hasSuffix("itemref"), let idref = attributeDict["idref"] {
                if attributeDict["linear"]?.lowercased() != "no" { spine.append(idref) }
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if collectingTitle { titleBuffer += string }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            if elementName.lowercased().hasSuffix("title"), collectingTitle {
                let value = titleBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                if title == nil && !value.isEmpty { title = value }
                collectingTitle = false
            }
        }
    }
}
