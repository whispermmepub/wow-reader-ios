import Foundation

struct Book: Identifiable, Codable, Hashable {
    enum Format: String, Codable {
        case epub
        case pdf
    }

    let id: UUID
    var title: String
    var fileName: String
    var format: Format
    var addedAt: Date
    var lastOpenedAt: Date?
    var progress: Double

    var fileExtension: String {
        format == .pdf ? "pdf" : "epub"
    }
}

enum LibrarySort: String, CaseIterable, Identifiable {
    case recentlyAdded
    case recentlyOpened
    case titleAscending
    case titleDescending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recentlyAdded: return "Recently added"
        case .recentlyOpened: return "Recently opened"
        case .titleAscending: return "Title A–Z / က–အ"
        case .titleDescending: return "Title Z–A / အ–က"
        }
    }
}
