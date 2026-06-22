import Foundation
import WebKit

@MainActor
final class ArticleWebViewPrewarmer {
    static let shared = ArticleWebViewPrewarmer()

    private var hasScheduledWarmUp = false
    private var warmWebView: WKWebView?

    private init() {}

    func warmUpIfNeeded() {
        guard !hasScheduledWarmUp else { return }
        hasScheduledWarmUp = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)

            let configuration = WKWebViewConfiguration()
            let webView = WKWebView(frame: .init(x: 0, y: 0, width: 1, height: 1), configuration: configuration)
            webView.isOpaque = false
            webView.backgroundColor = .clear
            webView.loadHTMLString(
                """
                <!doctype html>
                <html>
                <head><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
                <body></body>
                </html>
                """,
                baseURL: nil
            )
            warmWebView = webView
        }
    }
}
