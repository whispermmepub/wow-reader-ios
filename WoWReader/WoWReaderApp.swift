import SwiftUI

@main
struct WoWReaderApp: App {
    @StateObject private var library = LibraryStore()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(library)
                .onOpenURL { url in
                    library.importFromExternalURL(url)
                }
        }
    }
}
