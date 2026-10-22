import SwiftUI
import WebKit

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var popoverWebView: WKWebView?
    var settingsWindow: NSWindow?
    var settingsWindowDelegate: WindowDelegate?
    var installGuideWindow: NSWindow?
    var installGuideWindowDelegate: WindowDelegate?

    /// WKWebView.navigationDelegate 为 weak 引用，需强持有避免立即释放
    private let navigationDelegate = AppNavigationDelegate()

    /// popoverWebView 当前加载的站点，切换站点后需重新加载
    private var loadedSite: ChatSite?

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
        popover.delegate = self
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
                let size = fittedPopoverSize(for: WindowSizeManager.shared.currentWindowSize)
                popover.contentSize = size

                // 复用已有的 webView，如果不存在则创建
                let site = ChatSiteManager.shared.selectedSite
                let webView: WKWebView
                if let existing = popoverWebView {
                    webView = existing
                    // 加载应打开的 URL：webView 还没加载过任何页面，
                    // 或用户在设置中切换了站点导致当前页面不再匹配
                    if existing.url == nil || loadedSite != site {
                        loadURLInWebView(existing, urlString: NavigationHistoryManager.shared.urlToLoad())
                    }
                } else {
                    webView = createWebView(urlString: NavigationHistoryManager.shared.urlToLoad())
                    popoverWebView = webView
                    // 视图只在这里挂载一次：每次打开都重新赋值会让页面走一遍
                    // hidden → visible 的切换并触发重新合成，弹出首帧会卡顿
                    popover.contentViewController?.view = webView
                }
                loadedSite = site

                // 仅在尺寸变化时调整 frame，避免无谓的布局和网页 reflow
                if webView.frame.size != size {
                    webView.frame = NSRect(x: 0, y: 0, width: size.width, height: size.height)
                }

                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    // MARK: - NSPopoverDelegate

    /// 弹窗的窗口层级默认高于输入法候选窗：在 webview 里输入中文时，
    /// 候选词列表会被弹窗自己盖住，看不见候选词。
    /// 把弹窗降到 .floating：仍浮在其它 App 的普通窗口之上（弹窗窗口是
    /// 非激活面板，本 App 没被激活时 .normal 会被前台 App 的窗口盖住），
    /// 但低于输入法候选窗，候选词就能回到弹窗之上。
    ///
    /// 必须在 willShow 阶段设置：show 的弹出动画开始后再改窗口层级，
    /// WindowServer 会重新排序、重新合成，动画期间表现为卡顿/掉帧。
    func popoverWillShow(_ notification: Notification) {
        popover.contentViewController?.view.window?.level = .floating
    }

    func popoverDidShow(_ notification: Notification) {
        // 兜底：极少数情况下 willShow 时弹窗窗口尚未挂载
        if let window = popover.contentViewController?.view.window,
           window.level != .floating {
            window.level = .floating
        }
    }

    /// 弹窗锚定在菜单栏下方：尺寸超出屏幕可用区域时会压到 Dock 上，
    /// 而 .floating 层级的弹窗仍在 Dock 之下（网页底部的输入框会被 Dock 遮住），因此按屏幕可用区域收窄。
    private func fittedPopoverSize(for requested: NSSize) -> NSSize {
        guard let screen = statusItem.button?.window?.screen ?? NSScreen.main else {
            return requested
        }
        // 为弹窗箭头、阴影和 Dock 预留余量
        let availableWidth = max(320, screen.visibleFrame.width - 24)
        let availableHeight = max(240, screen.visibleFrame.height - 24)
        return NSSize(width: min(requested.width, availableWidth),
                      height: min(requested.height, availableHeight))
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
        // 导航代理持有站点，策略按页面所属站点判定
        navigationDelegate.site = ChatSiteManager.shared.selectedSite
        return WebViewFactory.create(urlString: urlString, navigationDelegate: navigationDelegate)
    }

    func loadURLInWebView(_ webView: WKWebView, urlString: String) {
        navigationDelegate.site = ChatSiteManager.shared.selectedSite
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
