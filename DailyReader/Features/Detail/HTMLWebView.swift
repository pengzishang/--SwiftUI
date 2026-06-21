import SwiftUI
import WebKit

struct HTMLWebView: UIViewRepresentable {
    let htmlBody: String
    let cssLinks: [String]
    let reloadToken: Int
    @Binding var contentHeight: CGFloat
    let onError: (String) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        let nextContentKey = "\(reloadToken)-\(wrappedHTML)"
        guard context.coordinator.loadedContentKey != nextContentKey else {
            context.coordinator.updateHeight(for: webView)
            return
        }
        context.coordinator.loadedContentKey = nextContentKey
        webView.loadHTMLString(wrappedHTML, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private var wrappedHTML: String {
        let css = cssLinks.map { "<link rel=\"stylesheet\" href=\"\($0)\">" }.joined(separator: "\n")
        return """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          \(css)
          <style>
            body { font: -apple-system-body; color: \(textColor); background: transparent; line-height: 1.65; padding: 0; margin: 0; }
            img { max-width: 100%; height: auto; border-radius: 12px; }
            a { color: #0A84FF; }
          </style>
        </head>
        <body>\(htmlBody)</body>
        </html>
        """
    }

    private var textColor: String {
        UIColor.label.resolvedColor(with: UITraitCollection.current).hexString
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: HTMLWebView
        var loadedContentKey: String?

        init(parent: HTMLWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            updateHeight(for: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.onError("文章内容加载失败，请重试")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.onError("文章内容加载失败，请重试")
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            parent.onError("文章内容加载失败，请重试")
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard
                navigationAction.navigationType == .linkActivated,
                let url = navigationAction.request.url,
                ["http", "https"].contains(url.scheme?.lowercased())
            else {
                decisionHandler(.allow)
                return
            }

            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        }

        func updateHeight(for webView: WKWebView) {
            webView.evaluateJavaScript(
                "Math.max(document.body.scrollHeight, document.documentElement.scrollHeight, document.body.offsetHeight, document.documentElement.offsetHeight);"
            ) { [weak self] result, _ in
                guard let self else { return }
                let measuredHeight: CGFloat
                if let value = result as? CGFloat {
                    measuredHeight = value
                } else if let value = result as? Double {
                    measuredHeight = CGFloat(value)
                } else if let value = result as? Int {
                    measuredHeight = CGFloat(value)
                } else {
                    measuredHeight = 0
                }

                let nextHeight = max(measuredHeight, 520)
                DispatchQueue.main.async {
                    if abs(self.parent.contentHeight - nextHeight) > 1 {
                        self.parent.contentHeight = nextHeight
                    }
                }
            }
        }
    }
}

private extension UIColor {
    var hexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: nil)
        return String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }
}
