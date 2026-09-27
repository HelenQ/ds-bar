import Foundation

/// 应用全局常量，集中管理版本号、默认值等
enum AppConstants {
    /// 应用显示名称
    static let appName = "DS Bar"

    /// 版本号（与 Info.plist 中 CFBundleShortVersionString 保持一致）
    static let version = "1.0.0"

    /// 版权信息
    static let copyright = "Copyright © 2026 hy"

    /// Bundle Identifier
    static let bundleIdentifier = "com.deepseek.dsbar"

    /// DeepSeek Chat 默认 URL
    static let defaultChatURL = "https://chat.deepseek.com/"

    /// DeepSeek 允许的域名列表（用于 WebView 导航策略限制）
    static let allowedDomains = [
        "chat.deepseek.com",
        "deepseek.com"
    ]

    // MARK: - 窗口尺寸

    /// 状态栏图标尺寸
    static let statusBarIconSize: CGFloat = 18

    /// 设置窗口默认尺寸
    static let settingsWindowSize = NSSize(width: 520, height: 400)

    /// 安装引导窗口默认尺寸
    static let installGuideWindowSize = NSSize(width: 460, height: 340)

    // MARK: - UserDefaults Keys

    enum UserDefaultsKey {
        static let windowPreset = "windowPreset"
        static let customWidth = "customWidth"
        static let customHeight = "customHeight"
        static let lastVisitedURL = "lastVisitedURL"
    }
}
