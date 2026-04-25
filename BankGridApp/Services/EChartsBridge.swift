import SwiftUI
import WebKit

struct EChartsBridge: UIViewRepresentable {
    let jsonData: String
    let isDark: Bool

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false

        if let url = Bundle.main.url(forResource: "echarts", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let theme = isDark ? "dark" : "light"
        webView.evaluateJavaScript("setTheme('\(theme)');") { _, _ in }
        let escaped = jsonData.replacingOccurrences(of: "\\", with: "\\\\")
                              .replacingOccurrences(of: "'", with: "\\'")
                              .replacingOccurrences(of: "\n", with: "\\n")
                              .replacingOccurrences(of: "\r", with: "\\r")
        webView.evaluateJavaScript("updateChart('\(escaped)');") { _, _ in }
    }
}
