import SwiftUI

@main
struct DSBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 空场景 - 我们使用 AppDelegate 手动管理窗口
        Settings {
            EmptyView()
        }
    }
}
