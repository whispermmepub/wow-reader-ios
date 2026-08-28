import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var importing = false

    private let columns = [GridItem(.adaptive(minimum: 152, maximum: 220), spacing: 16, alignment: .top)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    hero
                    explore
                    librarySection
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("WoW Reader")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $library.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search title or book")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort by", selection: $library.sort) {
                            ForEach(LibrarySort.allCases) { item in Text(item.title).tag(item) }
                        }
                    } label: { Image(systemName: "arrow.up.arrow.down.circle") }
                    Button { importing = true } label: { Image(systemName: "plus.circle.fill") }
                        .accessibilityLabel("Add book")
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Spacer()
                    Button { importing = true } label: {
                        Label("Add book", systemImage: "plus")
                            .font(.headline)
                            .padding(.horizontal, 19)
                            .padding(.vertical, 13)
                            .foregroundStyle(.white)
                            .background(.indigo.gradient, in: Capsule())
                            .shadow(color: .indigo.opacity(0.24), radius: 12, y: 6)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 18)
                    .padding(.bottom, 8)
                }
            }
            .fileImporter(isPresented: $importing,
                          allowedContentTypes: [UTType(importedAs: "org.idpf.epub-container"), .pdf],
                          allowsMultipleSelection: true) { result in
                guard case .success(let urls) = result else { return }
                for url in urls { library.importBook(url) }
            }
            .navigationDestination(for: Book.self) { book in
                ReaderView(book: book).environmentObject(library)
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Your books, ready to read").font(.title2.bold())
            Text("EPUB and PDF · local library · iPhone and iPad")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(LinearGradient(colors: [Color.indigo.opacity(0.14), Color.blue.opacity(0.08), Color.orange.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var explore: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Explore").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    exploreCard("Telegram", "New books", "paperplane.fill", .cyan, "https://t.me/TheBookR")
                    exploreCard("Discussion", "Reader community", "bubble.left.and.bubble.right.fill", .indigo, "https://t.me/+rUiqzi2mdhNiNGZl")
                    exploreCard("Website", "saroatsin.com", "globe", .green, "https://saroatsin.com")
                    exploreCard("Reviews", "Book reviews", "book.pages.fill", .orange, "https://whispermmepub.github.io/Review/")
                }
            }
        }
    }

    private func exploreCard(_ title: String, _ subtitle: String, _ symbol: String, _ tint: Color, _ url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 11) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold)).foregroundStyle(.white)
                    .frame(width: 42, height: 42).background(tint.gradient, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(width: 184, alignment: .leading).padding(13)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.primary.opacity(0.06), lineWidth: 0.7) }
        }
        .buttonStyle(.plain)
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Library").font(.title2.bold())
                    Text("\(library.visibleBooks.count) books").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Picker("Sort by", selection: $library.sort) {
                        ForEach(LibrarySort.allCases) { item in Text(item.title).tag(item) }
                    }
                } label: {
                    Label(library.sort.title, systemImage: "arrow.up.arrow.down").font(.caption.weight(.semibold))
                }
            }

            if library.visibleBooks.isEmpty {
                ContentUnavailableView(library.searchText.isEmpty ? "No books yet" : "No matching books",
                                       systemImage: "books.vertical",
                                       description: Text(library.searchText.isEmpty ? "Tap Add book to import EPUB or PDF files." : "Try another title or clear the search."))
                    .frame(maxWidth: .infinity).padding(.vertical, 36)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                    ForEach(library.visibleBooks) { book in
                        NavigationLink(value: book) {
                            BookCardView(book: book, fileURL: library.fileURL(for: book))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) { library.delete(book) } label: {
                                Label("Remove from Library", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
}
