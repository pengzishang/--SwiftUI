import SwiftUI
import WebKit

struct HTMLWebView: UIViewRepresentable {
    let htmlBody: String
    let cssLinks: [String]
    let reloadToken: Int
    let fontSize: Double
    @Binding var contentHeight: CGFloat
    let onImageTap: (String) -> Void
    let onError: (String) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "imageClicked")
        configuration.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        let nextContentKey = "\(reloadToken)-\(fontSize)-\(wrappedHTML)"
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
            body { font: -apple-system-body; color: \(textColor); background: transparent; line-height: 1.65; padding: 0; margin: 0; font-size: \(fontSize)px !important; }
            img { max-width: 100%; height: auto; border-radius: 12px; }
            .content img, .content-inner img {
              display: block !important;
              width: 100% !important;
              height: auto !important;
              border-radius: 12px !important;
              margin: 14px 0 !important;
            }
            .avatar, .author img, .meta img, .origin-source img, .source img {
              width: 32px !important;
              height: 32px !important;
              max-width: 32px !important;
              max-height: 32px !important;
              object-fit: cover;
              border-radius: 50% !important;
              vertical-align: middle;
              margin-right: 8px !important;
            }
            body > img:first-child, body > p:first-child img:first-child {
              max-width: 96px !important;
              max-height: 96px !important;
              object-fit: cover;
              border-radius: 18px;
              vertical-align: middle;
            }
            .meta {
              display: inline-flex !important;
              align-items: center !important;
              flex-wrap: wrap !important;
              background: rgba(120, 120, 128, 0.08) !important;
              padding: 6px 12px !important;
              border-radius: 20px !important;
              margin: 10px 0 18px 0 !important;
              border: 1px solid rgba(120, 120, 128, 0.12) !important;
            }
            .author {
              font-size: 14px !important;
              font-weight: 600 !important;
              color: \(textColor) !important;
            }
            .bio {
              font-size: 13px !important;
              color: #8E8E93 !important;
            }
            a { color: #0A84FF; }
            a.discussion-pill {
              display: flex !important;
              align-items: center !important;
              justify-content: center !important;
              box-sizing: border-box !important;
              width: calc(100% - 16px) !important;
              min-height: 44px !important;
              padding: 12px 16px !important;
              margin: 20px 8px 8px 8px !important;
              border-radius: 12px !important;
              background: rgba(10, 132, 255, 0.16) !important;
              color: #0A84FF !important;
              font-weight: 600 !important;
              text-decoration: none !important;
            }
            a.discussion-pill:active {
              background: rgba(10, 132, 255, 0.26) !important;
            }
          </style>
        </head>
        <body>
          \(htmlBody)
          <script>
            document.querySelectorAll('a').forEach(function(link) {
              if ((link.textContent || '').trim().indexOf('查看知乎讨论') !== -1) {
                link.classList.add('discussion-pill');
              }
            });
            document.querySelectorAll('img').forEach(function(img) {
              if (img.classList.contains('avatar') || img.closest('.avatar') || img.closest('.author') || img.closest('.source')) {
                return;
              }
              img.style.cursor = 'pointer';
              img.addEventListener('click', function() {
                window.webkit.messageHandlers.imageClicked.postMessage(img.src);
              });
            });
          </script>
        </body>
        </html>
        """
    }

    private var textColor: String {
        UIColor.label.resolvedColor(with: UITraitCollection.current).hexString
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: HTMLWebView
        var loadedContentKey: String?

        init(parent: HTMLWebView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "imageClicked", let imageUrl = message.body as? String {
                parent.onImageTap(imageUrl)
            }
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
