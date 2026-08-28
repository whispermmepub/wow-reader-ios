import SwiftUI

struct ReaderView: View {
    @EnvironmentObject private var library: LibraryStore
    let book: Book

    var body: some View {
        Group {
            if book.format == .pdf {
                PDFReaderView(url: library.fileURL(for: book)) { progress in
                    library.updateProgress(bookID: book.id, progress: progress)
                }
            } else {
                EPUBReaderView(book: book, url: library.fileURL(for: book)) { progress in
                    library.updateProgress(bookID: book.id, progress: progress)
                }
            }
        }
        .onAppear { library.markOpened(book) }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(true)
        .background(Color.black)
    }
}
