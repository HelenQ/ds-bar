import Foundation

/// 站点选择管理器：记住用户在设置中选择的聊天站点，下次打开沿用
final class ChatSiteManager {
    static let shared = ChatSiteManager()

    /// 内存缓存：导航决策等热路径会频繁读取，避免每次都查 UserDefaults
    private var cachedSite: ChatSite

    private init() {
        let raw = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKey.selectedChatSite)
        // 未设置或值非法时回退到 DeepSeek Chat
        cachedSite = raw.flatMap(ChatSite.init(rawValue:)) ?? .deepseek
    }

    /// 当前选中的站点（读缓存，写时同步落盘）
    var selectedSite: ChatSite {
        get { cachedSite }
        set {
            cachedSite = newValue
            UserDefaults.standard.set(newValue.rawValue, forKey: AppConstants.UserDefaultsKey.selectedChatSite)
        }
    }
}
