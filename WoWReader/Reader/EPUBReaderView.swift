import SwiftUI
import WebKit

struct EPUBReaderView: View {
    let book: Book
    let url: URL
    let onProgress: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var package: EPUBPackage?
    @State private var chapterIndex = 0
    @State private var controlsVisible = true
    @State private var showDisplayOptions = false
    @State private var errorMessage: String?

    @AppStorage("reader.theme") private var themeRaw = ReaderTheme.light.rawValue
    @AppStorage("reader.mode") private var modeRaw = EPUBReadingMode.page.rawValue
    @AppStorage("reader.fontScale") private var fontScale = 1.0
    @AppStorage("reader.lineHeight") private var lineHeight = 1.6
    @AppStorage("reader.margin") private var margin = 5.0

    private var theme: ReaderTheme {
        get { ReaderTheme(rawValue: themeRaw) ?? .light }
        nonmutating set { themeRaw = newValue.rawValue }
    }

    private var mode: EPUBReadingMode {
        get { EPUBReadingMode(rawValue: modeRaw) ?? .page }
        nonmutating set { modeRaw = newValue.rawValue }
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            if let package, package.chapters.indices.contains(chapterIndex) {
                EPUBWebView(
                    chapter: package.chapters[chapterIndex],
                    rootURL: package.rootURL,
                    configuration: .init(theme: theme, mode: mode, fontScale: fontScale, lineHeight: lineHeight, margin: margin),
                    onChapterBoundary: turnChapter,
                    onToggleControls: toggleControls,
                    onLocalProgress: reportLocalProgress
                )
                .ignoresSafeArea()
            } else if let errorMessage {
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundStyle(.orange)
                    Text("Unable to open EPUB").font(.headline)
                    Text(errorMessage).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Close") { dismiss() }.buttonStyle(.borderedProminent)
                }
                .padding(28)
            } else {
                ProgressView("Preparing book…")
                    .tint(theme == .dark ? .white : .indigo)
                    .foregroundStyle(theme == .dark ? .white : .primary)
            }

            if controlsVisible, let package {
                readerChrome(package)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }
        }
        .task(id: url) { await loadBook() }
        .sheet(isPresented: $showDisplayOptions) {
            DisplayOptionsSheet(
                theme: Binding(get: { theme }, set: { theme = $0 }),
                mode: Binding(get: { mode }, set: { mode = $0 }),
                fontScale: $fontScale,
                lineHeight: $lineHeight,
                margin: $margin
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .preferredColorScheme(theme == .dark ? .dark : .light)
    }

    @ViewBuilder
    private func readerChrome(_ package: EPUBPackage) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").frame(width: 40, height: 40)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(package.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text(package.chapters[chapterIndex].title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Menu {
                    ForEach(Array(package.chapters.enumerated()), id: \.element.id) { index, chapter in
                        Button {
                            chapterIndex = index
                            reportLocalProgress(0)
                        } label: {
                            if index == chapterIndex {
                                Label(chapter.title, systemImage: "checkmark")
                            } else {
                                Text(chapter.title)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "list.bullet").frame(width: 40, height: 40)
                }
                Button { showDisplayOptions = true } label: {
                    Text("Aa").font(.headline).frame(width: 40, height: 40)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Spacer()

            HStack(spacing: 18) {
                Button { turnChapter(-1) } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .disabled(chapterIndex == 0)

                Spacer()
                Text("\(chapterIndex + 1) / \(package.chapters.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()

                Button { turnChapter(1) } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
                .disabled(chapterIndex >= package.chapters.count - 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 46)
            .padding(.bottom, 10)
        }
        .foregroundStyle(theme == .dark ? Color.white : Color.primary)
    }

    private func loadBook() async {
        do {
            let prepared = try await Task.detached(priority: .userInitiated) {
                try EPUBDocument.prepare(at: url)
            }.value
            package = prepared
            let initial = Int((book.progress * Double(max(1, prepared.chapters.count))).rounded(.down))
            chapterIndex = min(max(0, initial), prepared.chapters.count - 1)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func turnChapter(_ delta: Int) {
        guard let package else { return }
        let next = min(max(0, chapterIndex + delta), package.chapters.count - 1)
        guard next != chapterIndex else { return }
        chapterIndex = next
        reportLocalProgress(delta > 0 ? 0 : 1)
    }

    private func reportLocalProgress(_ local: Double) {
        guard let package, !package.chapters.isEmpty else { return }
        let overall = (Double(chapterIndex) + min(1, max(0, local))) / Double(package.chapters.count)
        onProgress(min(1, max(0, overall)))
    }

    private func toggleControls() {
        withAnimation(.easeOut(duration: 0.18)) { controlsVisible.toggle() }
    }
}

private struct EPUBWebConfiguration: Equatable {
    let theme: ReaderTheme
    let mode: EPUBReadingMode
    let fontScale: Double
    let lineHeight: Double
    let margin: Double
}

private struct EPUBWebView: UIViewRepresentable {
    let chapter: EPUBChapter
    let rootURL: URL
    let configuration: EPUBWebConfiguration
    let onChapterBoundary: (Int) -> Void
    let onToggleControls: () -> Void
    let onLocalProgress: (Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChapterBoundary: onChapterBoundary, onToggleControls: onToggleControls, onLocalProgress: onLocalProgress)
    }

    func makeUIView(context: Context) -> WKWebView {
        let content = WKUserContentController()
        content.add(context.coordinator, name: "readerTap")
        let config = WKWebViewConfiguration()
        config.userContentController = content
        config.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.bounces = false
        webView.scrollView.decelerationRate = .fast
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        context.coordinator.webView = webView
        context.coordinator.configuration = configuration
        context.coordinator.chapterURL = chapter.url
        webView.loadFileURL(chapter.url, allowingReadAccessTo: rootURL)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onChapterBoundary = onChapterBoundary
        context.coordinator.onToggleControls = onToggleControls
        context.coordinator.onLocalProgress = onLocalProgress

        if context.coordinator.chapterURL != chapter.url {
            context.coordinator.chapterURL = chapter.url
            context.coordinator.configuration = configuration
            webView.loadFileURL(chapter.url, allowingReadAccessTo: rootURL)
        } else if context.coordinator.configuration != configuration {
            context.coordinator.configuration = configuration
            context.coordinator.applyStyle()
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "readerTap")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, UIScrollViewDelegate {
        weak var webView: WKWebView?
        var chapterURL: URL?
        var configuration: EPUBWebConfiguration?
        var onChapterBoundary: (Int) -> Void
        var onToggleControls: () -> Void
        var onLocalProgress: (Double) -> Void

        init(onChapterBoundary: @escaping (Int) -> Void,
             onToggleControls: @escaping () -> Void,
             onLocalProgress: @escaping (Double) -> Void) {
            self.onChapterBoundary = onChapterBoundary
            self.onToggleControls = onToggleControls
            self.onLocalProgress = onLocalProgress
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.scrollView.delegate = self
            applyStyle()
            installTapScript()
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "readerTap", let value = message.body as? Int else { return }
            if value == 0 { onToggleControls(); return }
            turnPage(value)
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { reportProgress() }
        func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) { reportProgress() }
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard configuration?.mode == .scroll else { return }
            reportProgress()
        }

        func applyStyle() {
            guard let webView, let configuration else { return }
            let scale = max(0.75, min(2.2, configuration.fontScale))
            let line = max(1.15, min(2.2, configuration.lineHeight))
            let margin = max(3, min(16, configuration.margin))
            let pageCSS: String
            if configuration.mode == .page {
                pageCSS = "html,body{height:100%!important;overflow:hidden!important;}body{height:100vh!important;column-fill:auto!important;column-width:\(100 - margin * 2)vw!important;column-gap:\(margin * 2)vw!important;}"
                webView.scrollView.isPagingEnabled = true
                webView.scrollView.alwaysBounceVertical = false
            } else {
                pageCSS = "html{overflow-x:hidden!important;}body{height:auto!important;max-width:900px!important;margin:0 auto!important;}"
                webView.scrollView.isPagingEnabled = false
                webView.scrollView.alwaysBounceVertical = true
            }
            let css = """
            html,body{background:\(configuration.theme.backgroundHex)!important;color:\(configuration.theme.foregroundHex)!important;margin:0!important;padding:0!important;}
            body{font-size:\(scale * 100)%!important;line-height:\(line)!important;padding:4.2vh \(margin)vw 7vh \(margin)vw!important;box-sizing:border-box!important;text-align:justify!important;text-justify:inter-character!important;word-spacing:normal!important;letter-spacing:normal!important;}
            body,p,div,span,li,blockquote,dd,dt{color:\(configuration.theme.foregroundHex)!important;}
            h1,h2,h3,h4,h5,h6,strong,b{color:\(configuration.theme.foregroundHex)!important;}
            img,svg,video,table{max-width:100%!important;height:auto!important;}
            a{color:#6D8BFF!important;}
            \(pageCSS)
            """
            let escaped = css.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "`", with: "\\`")
            let js = """
            (function(){
              var s=document.getElementById('wow-ios-style');
              if(!s){s=document.createElement('style');s.id='wow-ios-style';document.head.appendChild(s);}
              s.textContent=`\(escaped)`;
            })();
            """
            webView.evaluateJavaScript(js)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in self?.reportProgress() }
        }

        private func installTapScript() {
            let js = """
            (function(){
              if(window.__wowTapInstalled)return;window.__wowTapInstalled=true;
              document.addEventListener('click',function(e){
                try{
                  if(e.target&&e.target.closest&&e.target.closest('a'))return;
                  var sel=window.getSelection&&String(window.getSelection());if(sel&&sel.length>0)return;
                  var r=e.clientX/Math.max(1,window.innerWidth);
                  var v=r<0.32?-1:(r>0.68?1:0);
                  window.webkit.messageHandlers.readerTap.postMessage(v);
                }catch(_e){}
              },true);
            })();
            """
            webView?.evaluateJavaScript(js)
        }

        private func turnPage(_ direction: Int) {
            guard let webView, configuration?.mode == .page else {
                onChapterBoundary(direction)
                return
            }
            let scroll = webView.scrollView
            let width = max(1, scroll.bounds.width)
            let maxX = max(0, scroll.contentSize.width - width)
            let current = scroll.contentOffset.x
            let target = min(max(0, current + CGFloat(direction) * width), maxX)
            if abs(target - current) < width * 0.35 {
                onChapterBoundary(direction)
            } else {
                scroll.setContentOffset(CGPoint(x: target, y: 0), animated: false)
                reportProgress()
            }
        }

        private func reportProgress() {
            guard let webView else { return }
            let scroll = webView.scrollView
            if configuration?.mode == .page {
                let maxX = max(1, scroll.contentSize.width - scroll.bounds.width)
                onLocalProgress(min(1, max(0, scroll.contentOffset.x / maxX)))
            } else {
                let maxY = max(1, scroll.contentSize.height - scroll.bounds.height)
                onLocalProgress(min(1, max(0, scroll.contentOffset.y / maxY)))
            }
        }
    }
}

private struct DisplayOptionsSheet: View {
    @Binding var theme: ReaderTheme
    @Binding var mode: EPUBReadingMode
    @Binding var fontScale: Double
    @Binding var lineHeight: Double
    @Binding var margin: Double

    var body: some View {
        NavigationStack {
            Form {
                Section("Theme") {
                    Picker("Theme", selection: $theme) {
                        ForEach(ReaderTheme.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Reading") {
                    Picker("Mode", selection: $mode) {
                        ForEach(EPUBReadingMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Text") {
                    LabeledContent("Font size", value: "\(Int(fontScale * 100))%")
                    Slider(value: $fontScale, in: 0.8...1.8, step: 0.05)
                    LabeledContent("Line height", value: String(format: "%.1f", lineHeight))
                    Slider(value: $lineHeight, in: 1.2...2.0, step: 0.1)
                    LabeledContent("Margins", value: "\(Int(margin))%")
                    Slider(value: $margin, in: 3...14, step: 1)
                }
            }
            .navigationTitle("Display options")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
