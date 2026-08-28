# WoW Reader for iOS

Native SwiftUI iPhone/iPad reader for EPUB and PDF.

## Current foundation

- Responsive iPhone/iPad library
- Files / Open-in import flow
- EPUB reading with WKWebView
- PDF reading with PDFKit
- Light, Sepia and Dark reader themes
- Page/scroll-ready reader architecture
- Local reading progress and library metadata
- Edge-to-edge reader chrome

## Build

The repository uses XcodeGen so the Xcode project stays reproducible.

```bash
brew install xcodegen
xcodegen generate
open WoWReader.xcodeproj
```

Bundle identifier: `com.whisper.wowreader`

The GitHub Actions workflow generates the project and performs an unsigned iOS Simulator build on macOS.
