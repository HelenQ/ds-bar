import Foundation

/// 导航历史管理器：记录用户在 WebView 中最后访问的 URL
///
/// 打开 WebView 时，优先加载上次最后访问的 URL；
/// 没有历史记录时，加载默认页 (https://chat.deepseek.com/)
final class NavigationHistoryManager {
    static let shared = NavigationHistoryManager()

    /// 默认首页
    static let defaultURL = AppConstants.defaultChatURL

    /// 上次最后访问的 URL
    var lastVisitedURL: String {
        let saved = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKey.lastVisitedURL)
        return saved ?? NavigationHistoryManager.defaultURL
    }

    /// 是否有历史记录（即用户曾经导航离开过默认页）
    var hasHistory: Bool {
        UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKey.lastVisitedURL) != nil
    }

    private init() {}

    /// 更新最后访问的 URL（仅记录 http/https）
    func updateLastVisited(_ urlString: String) {
        guard let url = URL(string: urlString),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme) else { return }

        // 忽略 about:blank、data: 等内部 URL
        UserDefaults.standard.set(urlString, forKey: AppConstants.UserDefaultsKey.lastVisitedURL)
    }

    /// 获取应该打开的 URL：优先上次访问的，否则默认页
    func urlToLoad() -> String {
        return lastVisitedURL
    }

    /// 清除历史，下次将打开默认页
    func clearHistory() {
        UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaultsKey.lastVisitedURL)
    }
}
