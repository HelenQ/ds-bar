import Foundation

/// 支持的聊天站点
///
/// 设置页下拉列表展示 `displayName`，选中后 WebView 加载对应的 `url`，
/// 导航仅放行 `allowedDomains` 及其子域名。
enum ChatSite: String, CaseIterable, Identifiable {
    case deepseek
    case qianwen

    var id: String { rawValue }

    /// 站点名称（设置页下拉列表展示）
    var displayName: String {
        switch self {
        case .deepseek: return "DeepSeek Chat"
        case .qianwen:  return "通义千问"
        }
    }

    /// 站点首页地址
    var url: String {
        switch self {
        case .deepseek:
            return "https://chat.deepseek.com/"
        case .qianwen:
            // 不能用裸域 https://qianwen.com/：它会 301 到 http://www.qianwen.com/，
            // 这一跳是明文 HTTP，会被 App Transport Security 拦截导致加载失败。
            // www 主机直接以 HTTPS 返回 200，没有这一跳。
            return "https://www.qianwen.com/"
        }
    }

    /// 允许在 WebView 内打开的域名（含子域名），其余链接交给默认浏览器。
    /// 这里尽量收窄：域名放得越宽，越多无关页会被留在弹窗内打开。
    var allowedDomains: [String] {
        switch self {
        case .deepseek:
            return ["chat.deepseek.com", "deepseek.com"]
        case .qianwen:
            // 登录/授权走阿里账号体系（待实测确认，若登录被踢到浏览器再补域名）
            return ["qianwen.com", "aliyun.com"]
        }
    }
}
