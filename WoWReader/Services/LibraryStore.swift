import Foundation

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var books: [Book] = []
    @Published var sort: LibrarySort = .recentlyAdded
    @Published var searchText: String = ""

    private let fileManager = FileManager.default
    private let rootURL: URL
    private let booksURL: URL
    private let metadataURL: URL

    init() {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        rootURL = base.appendingPathComponent("WoWReader", isDirectory: true)
        booksURL = rootURL.appendingPathComponent("Books", isDirectory: true)
        metadataURL = rootURL.appendingPathComponent("library.json")
        try? fileManager.createDirectory(at: booksURL, withIntermediateDirectories: true)
        load()
    }

    var visibleBooks: [Book] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = query.isEmpty ? books : books.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.fileName.localizedCaseInsensitiveContains(query)
        }

        switch sort {
        case .recentlyAdded:
            result.sort { $0.addedAt > $1.addedAt }
        case .recentlyOpened:
            result.sort { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
        case .titleAscending:
            result.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .titleDescending:
            result.sort { $0.title.localizedStandardCompare($1.title) == .orderedDescending }
        }
        return result
    }

    func fileURL(for book: Book) -> URL {
        booksURL.appendingPathComponent(book.fileName)
    }

    func importFromExternalURL(_ url: URL) {
        importBook(url)
    }

    func importBook(_ sourceURL: URL) {
        let ext = sourceURL.pathExtension.lowercased()
        guard ext == "epub" || ext == "pdf" else { return }

        let scoped = sourceURL.startAccessingSecurityScopedResource()
        defer { if scoped { sourceURL.stopAccessingSecurityScopedResource() } }

        do {
            let id = UUID()
            let storedName = id.uuidString + "." + ext
            let destination = booksURL.appendingPathComponent(storedName)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: sourceURL, to: destination)

            let fallbackTitle = sourceURL.deletingPathExtension().lastPathComponent
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let format: Book.Format = ext == "pdf" ? .pdf : .epub
            let book = Book(
                id: id,
                title: fallbackTitle.isEmpty ? "Book" : fallbackTitle,
                fileName: storedName,
                format: format,
                addedAt: Date(),
                lastOpenedAt: nil,
                progress: 0
            )
            books.append(book)
            save()

            if format == .epub {
                Task.detached(priority: .utility) { [destination] in
                    let title = try? EPUBDocument.metadataTitle(at: destination)
                    guard let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    await MainActor.run {
                        self.rename(bookID: id, title: title)
                    }
                }
            }
        } catch {
            print("WoW Reader import failed: \(error)")
        }
    }

    func markOpened(_ book: Book) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[index].lastOpenedAt = Date()
        save()
    }

    func updateProgress(bookID: UUID, progress: Double) {
        guard let index = books.firstIndex(where: { $0.id == bookID }) else { return }
        books[index].progress = min(1, max(0, progress))
        save()
    }

    func delete(_ book: Book) {
        try? fileManager.removeItem(at: fileURL(for: book))
        books.removeAll { $0.id == book.id }
        save()
    }

    private func rename(bookID: UUID, title: String) {
        guard let index = books.firstIndex(where: { $0.id == bookID }) else { return }
        books[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: metadataURL),
              let decoded = try? JSONDecoder().decode([Book].self, from: data) else {
            books = []
            return
        }
        books = decoded.filter { fileManager.fileExists(atPath: fileURL(for: $0).path) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(books) else { return }
        try? fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try? data.write(to: metadataURL, options: .atomic)
    }
}
