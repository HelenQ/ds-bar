import AppKit
import WebKit

// MARK: - WebView 工厂

/// WKWebView 创建与配置
enum WebViewFactory {

    /// 创建配置好的 WKWebView
    static func create(urlString: String, navigationDelegate: WKNavigationDelegate) -> WKWebView {
        let config = WKWebViewConfiguration()
        // 启用开发者工具（通过 KVC 设置私有属性）
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        if #available(macOS 13.3, *) {
            config.preferences.isElementFullscreenEnabled = true
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = navigationDelegate

        loadURL(webView, urlString: urlString)

        return webView
    }

    /// 在 WebView 中加载 URL
    static func loadURL(_ webView: WKWebView, urlString: String) {
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
    }
}

// MARK: - 导航错误页面

/// WebView 导航失败时的错误页面 HTML
enum NavigationErrorPage {

    /// - Parameter site: 加载失败的站点。错误页以 `loadHTMLString(baseURL: nil)` 呈现，
    ///   文档 URL 是 about:blank，`location.reload()` 只会重载错误页自身，
    ///   因此「重试」直接跳回站点首页。
    static func html(for error: Error, site: ChatSite) -> String {
        return """
        <html>
        <body style="display:flex;justify-content:center;align-items:center;height:100vh;margin:0;background:#1a1a2e;color:#e0e0e0;font-family:-apple-system,BlinkMacSystemFont,sans-serif;">
            <div style="text-align:center;">
                <div style="font-size:48px;margin-bottom:16px;">⚠️</div>
                <h2 style="margin:0 0 8px 0;">连接失败</h2>
                <p style="color:#aaa;">无法连接到 \(site.displayName)</p>
                <p style="color:#666;font-size:12px;">\(error.localizedDescription)</p>
                <button onclick="location.href='\(site.url)'" style="margin-top:16px;padding:8px 24px;border:1px solid #3169FA;background:transparent;color:#3169FA;border-radius:6px;cursor:pointer;font-size:14px;">重试</button>
            </div>
        </body>
        </html>
        """
    }
}

// MARK: - WKNavigationDelegate

/// 应用统一的导航代理：域名限制、历史记录、错误处理
class AppNavigationDelegate: NSObject, WKNavigationDelegate {

    /// 当前 WebView 中页面所属的站点。导航策略按页面自身站点判定，
    /// 而不是读设置里的最新选择 —— 设置变更后页面会重新加载，
    /// 切换的瞬间不该把还挂着的旧页面按新站点白名单判定。
    var site: ChatSite = .deepseek

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url,
              let host = url.host else {
            decisionHandler(.allow)
            return
        }

        // 仅允许当前页面所属站点的域名（含子域名）
        let isAllowed = site.allowedDomains.contains { domain in
            host == domain || host.hasSuffix(".\(domain)")
        }

        if isAllowed {
            decisionHandler(.allow)
        } else {
            // 外部链接在默认浏览器中打开
            if navigationAction.navigationType == .linkActivated {
                NSWorkspace.shared.open(url)
            }
            decisionHandler(.cancel)
        }
    }

    /// 页面主框架导航完成时，记录 URL 到历史
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url, !url.absoluteString.isEmpty {
            NavigationHistoryManager.shared.updateLastVisited(url.absoluteString)
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        webView.loadHTMLString(NavigationErrorPage.html(for: error, site: site), baseURL: nil)
    }
}
