import SwiftUI
import WebKit

struct HTMLWebView: UIViewRepresentable {
    let htmlBody: String
    let cssLinks: [String]

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(wrappedHTML, baseURL: nil)
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
