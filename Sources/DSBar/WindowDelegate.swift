import AppKit

/// 通用窗口委托，在窗口关闭时执行回调
///
/// 用于解决 NSWindow.delegate 为 weak 引用导致立即释放的问题：
/// 调用方需同时持有 window 和 delegate（如 `settingsWindow` / `settingsWindowDelegate`）
class WindowDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
