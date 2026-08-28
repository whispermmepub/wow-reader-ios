import SwiftUI
import PDFKit

struct PDFReaderView: View {
    let url: URL
    let onProgress: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var controlsVisible = true

    var body: some View {
        ZStack {
            PDFKitView(url: url, onProgress: onProgress)
                .ignoresSafeArea()
                .background(Color.black)

            if controlsVisible {
                VStack {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.headline)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.18)) { controlsVisible.toggle() }
        }
        .preferredColorScheme(.dark)
    }
}

private struct PDFKitView: UIViewRepresentable {
    let url: URL
    let onProgress: (Double) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onProgress: onProgress) }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.backgroundColor = .black
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        view.pageBreakMargins = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        view.document = PDFDocument(url: url)
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }

    static func dismantleUIView(_ uiView: PDFView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject {
        private weak var pdfView: PDFView?
        private let onProgress: (Double) -> Void
        private var observer: NSObjectProtocol?

        init(onProgress: @escaping (Double) -> Void) {
            self.onProgress = onProgress
        }

        func attach(to view: PDFView) {
            pdfView = view
            observer = NotificationCenter.default.addObserver(
                forName: .PDFViewPageChanged,
                object: view,
                queue: .main
            ) { [weak self] _ in self?.reportProgress() }
            reportProgress()
        }

        func detach() {
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
        }

        private func reportProgress() {
            guard let view = pdfView,
                  let document = view.document,
                  document.pageCount > 0,
                  let current = view.currentPage else { return }
            let index = document.index(for: current)
            let progress = Double(index + 1) / Double(document.pageCount)
            onProgress(min(1, max(0, progress)))
        }
    }
}
