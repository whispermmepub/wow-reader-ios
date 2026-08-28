import SwiftUI

enum ReaderTheme: String, CaseIterable, Identifiable {
    case light
    case sepia
    case dark

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var background: Color {
        switch self {
        case .light: return Color.white
        case .sepia: return Color(red: 0.96, green: 0.93, blue: 0.84)
        case .dark: return Color(red: 0.07, green: 0.07, blue: 0.08)
        }
    }

    var foregroundHex: String {
        switch self {
        case .light: return "#202124"
        case .sepia: return "#2A2721"
        case .dark: return "#E8EAED"
        }
    }

    var backgroundHex: String {
        switch self {
        case .light: return "#FFFFFF"
        case .sepia: return "#F4ECD8"
        case .dark: return "#121212"
        }
    }
}

enum EPUBReadingMode: String, CaseIterable, Identifiable {
    case page
    case scroll

    var id: String { rawValue }
    var title: String { self == .page ? "Pages" : "Scroll" }
}
