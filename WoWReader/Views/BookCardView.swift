import SwiftUI
import QuickLookThumbnailing

struct BookCardView: View {
    let book: Book
    let fileURL: URL
    @State private var thumbnail: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.indigo.opacity(0.16), Color.blue.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: book.format == .pdf ? "doc.richtext" : "book.closed.fill")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(.indigo)
                        Text(book.format.rawValue.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .aspectRatio(0.68, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.primary.opacity(0.06), lineWidth: 0.7)
            }
            .shadow(color: .black.opacity(0.08), radius: 9, y: 5)

            Text(book.title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if book.progress > 0.001 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Int(book.progress * 100))% read")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressView(value: book.progress)
                        .tint(.indigo)
                }
            } else {
                Text(book.format == .pdf ? "PDF" : "EPUB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .task(id: fileURL) {
            await loadThumbnail()
        }
    }

    @MainActor
    private func loadThumbnail() async {
        guard thumbnail == nil else { return }
        let size = CGSize(width: 420, height: 620)
        let scale = UIScreen.main.scale
        let request = QLThumbnailGenerator.Request(
            fileAt: fileURL,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )
        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            thumbnail = representation.uiImage
        } catch {
            thumbnail = nil
        }
    }
}
