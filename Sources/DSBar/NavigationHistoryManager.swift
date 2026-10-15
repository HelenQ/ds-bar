import Foundation

/// 导航历史管理器：记录用户在 WebView 中最后访问的 URL
///
/// 打开 WebView 时，优先加载上次最后访问的 URL；
/// 没有历史记录时，加载当前站点的首页。
/// 历史按站点分别记录，切换站点不会串页。
final class NavigationHistoryManager {
    static let shared = NavigationHistoryManager()

    /// 默认首页（当前选中的站点）
    static var defaultURL: String { ChatSiteManager.shared.selectedSite.url }

    /// 当前站点对应的历史存储 key
    private var historyKey: String {
        "\(AppConstants.UserDefaultsKey.lastVisitedURL).\(ChatSiteManager.shared.selectedSite.rawValue)"
    }

    /// 已保存的 URL：先读当前站点的键，再回退到旧版本的全局键
    /// （旧版本只有 DeepSeek，所以历史只可能属于它，避免老用户丢失「上次访问页」）
    private var savedURL: String? {
        if let saved = UserDefaults.standard.string(forKey: historyKey) { return saved }
        guard ChatSiteManager.shared.selectedSite == .deepseek else { return nil }
        return UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKey.lastVisitedURL)
    }

    /// 上次最后访问的 URL
    var lastVisitedURL: String {
        return savedURL ?? NavigationHistoryManager.defaultURL
    }

    /// 是否有历史记录（即用户曾经导航离开过默认页）
    var hasHistory: Bool {
        return savedURL != nil
    }

    private init() {}

    /// 更新最后访问的 URL（仅记录 http/https）
    func updateLastVisited(_ urlString: String) {
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme) else { return }

        // 忽略 about:blank、data: 等内部 URL
        UserDefaults.standard.set(urlString, forKey: historyKey)
    }

    /// 获取应该打开的 URL：优先上次访问的，否则默认页
    func urlToLoad() -> String {
        return lastVisitedURL
    }

    /// 清除历史，下次将打开默认页
    func clearHistory() {
        UserDefaults.standard.removeObject(forKey: historyKey)
    }
}
