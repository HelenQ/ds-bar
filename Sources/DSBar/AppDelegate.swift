import SwiftUI
import WebKit

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var popoverWebView: WKWebView?
    var settingsWindow: NSWindow?
    var settingsWindowDelegate: WindowDelegate?
    var installGuideWindow: NSWindow?
    var installGuideWindowDelegate: WindowDelegate?

    /// WKWebView.navigationDelegate 为 weak 引用，需强持有避免立即释放
    private let navigationDelegate = AppNavigationDelegate()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 隐藏 Dock 图标，使应用仅驻留在菜单栏
        NSApp.setActivationPolicy(.accessory)

        // 检查是否安装在 /Applications 下，若不在则提示引导安装
        checkInstallationLocation()

        // 创建状态栏图标
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = statusItem

        // 设置菜单栏图标
        if let button = statusItem.button {
            // 使用自定义图标
            if let icon = NSImage(named: "statusbar") {
                icon.isTemplate = true  // 模板图标，系统自动适配明暗模式
                button.image = icon
                button.image?.size = NSSize(width: AppConstants.statusBarIconSize,
                                             height: AppConstants.statusBarIconSize)
            } else {
                // fallback 到 SF Symbol
                button.image = NSImage(systemSymbolName: "bubble.left.and.bubble.right.fill",
                                        accessibilityDescription: AppConstants.appName)
                button.image?.size = NSSize(width: AppConstants.statusBarIconSize,
                                             height: AppConstants.statusBarIconSize)
            }
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // 创建 Popover（点击菜单栏图标时弹出的内容）
        let popover = NSPopover()
        let initialSize = WindowSizeManager.shared.currentWindowSize
        popover.contentSize = initialSize
        popover.behavior = .transient
        popover.contentViewController = NSViewController()
        self.popover = popover
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 落盘尚未写入的窗口尺寸变更（防抖延迟中）
        WindowSizeManager.shared.flushPendingSave()
    }

    // MARK: - Status Bar 交互

    @objc func statusBarButtonClicked(_ sender: AnyObject?) {
        if let event = NSApp.currentEvent {
            if event.type == .rightMouseUp {
                showContextMenu()
                return
            }
        }
        togglePopover()
    }

    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                let size = WindowSizeManager.shared.currentWindowSize
                popover.contentSize = size

                // 复用已有的 webView，如果不存在则创建
                let webView: WKWebView
                if let existing = popoverWebView {
                    webView = existing
                    // 刷新到当前应加载的 URL（如果 webView 还没加载过任何页面）
                    if existing.url == nil {
                        loadURLInWebView(existing, urlString: NavigationHistoryManager.shared.urlToLoad())
                    }
                } else {
                    webView = createWebView(urlString: NavigationHistoryManager.shared.urlToLoad())
                    popoverWebView = webView
                }

                webView.frame = NSRect(x: 0, y: 0, width: size.width, height: size.height)
                popover.contentViewController?.view = webView

                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    func showContextMenu() {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "打开", action: #selector(togglePopover), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        let settingsItem = NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "关于 \(AppConstants.appName)", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "退出 \(AppConstants.appName)", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        if let button = statusItem.button {
            let point = NSPoint(x: button.bounds.origin.x,
                                y: button.bounds.origin.y + button.bounds.height)
            menu.popUp(positioning: nil, at: point, in: button)
        }
    }

    // MARK: - 创建 WebView

    func createWebView(urlString: String) -> WKWebView {
        WebViewFactory.create(urlString: urlString, navigationDelegate: navigationDelegate)
    }

    func loadURLInWebView(_ webView: WKWebView, urlString: String) {
        WebViewFactory.loadURL(webView, urlString: urlString)
    }

    // MARK: - 打开设置窗口

    @objc func openSettings() {
        if popover.isShown {
            popover.performClose(nil)
        }

        if let existingWindow = settingsWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
            .environmentObject(WindowSizeManager.shared)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: AppConstants.settingsWindowSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(AppConstants.appName) 设置"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.center()

        let delegate = WindowDelegate(onClose: { [weak self] in
            self?.settingsWindow = nil
        })
        self.settingsWindowDelegate = delegate
        window.delegate = delegate

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.settingsWindow = window
    }

    // MARK: - 关于 & 退出

    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - 安装引导

    /// 首次启动时，如果不在 /Applications 下，弹窗引导用户拖拽安装
    private func checkInstallationLocation() {
        if LaunchAtLoginManager.isProperlyInstalled { return }

        // 延迟显示，等菜单栏图标就绪
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showInstallGuide()
        }
    }

    private func showInstallGuide() {
        // 如果已有安装引导窗口，前置显示
        if let existing = installGuideWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let bundlePath = Bundle.main.bundlePath

        let guideView = InstallGuideView(bundlePath: bundlePath)

        let hostingController = NSHostingController(rootView: guideView)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: AppConstants.installGuideWindowSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "安装 \(AppConstants.appName)"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.center()

        let delegate = WindowDelegate(onClose: { [weak self] in
            self?.installGuideWindow = nil
            // 恢复为菜单栏应用（无 Dock 图标）
            NSApp.setActivationPolicy(.accessory)
        })
        self.installGuideWindowDelegate = delegate
        window.delegate = delegate

        // 临时切换为 regular app 以显示窗口
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.installGuideWindow = window
    }
}
