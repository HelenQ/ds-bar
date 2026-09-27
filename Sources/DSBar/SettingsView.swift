import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var windowManager: WindowSizeManager
    @State private var launchAtLogin = LaunchAtLoginManager.isEnabled
    @State private var launchError: String?

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("通用", systemImage: "gearshape")
                }

            appearanceTab
                .tabItem {
                    Label("外观", systemImage: "macwindow")
                }

            aboutTab
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .frame(minWidth: 480, minHeight: 340)
    }

    // MARK: - 通用设置

    private var generalTab: some View {
        Form {
            Section(header: Label("启动", systemImage: "power").font(.headline)) {
                Toggle("开机自启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        if let error = LaunchAtLoginManager.setEnabled(newValue) {
                            // 注册返回了需要用户操作的信息
                            launchError = error
                            // 不回拨 toggle，保持开启状态让用户看到提示
                        } else {
                            launchError = nil
                        }
                        // 重新读取实际状态
                        launchAtLogin = LaunchAtLoginManager.isEnabled
                    }

                // 显示当前状态
                HStack {
                    Text("状态")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(LaunchAtLoginManager.statusDescription)
                        .font(.caption)
                        .foregroundColor(launchAtLogin ? .green : .secondary)
                }

                if let error = launchError {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                        Button("打开系统设置 > 登录项") {
                            LaunchAtLoginManager.openLoginItemsSettings()
                        }
                        .font(.caption)
                        .controlSize(.small)
                    }
                }

                Text("启用后，\(AppConstants.appName) 将在登录时自动启动并驻留在菜单栏")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !LaunchAtLoginManager.isProperlyInstalled {
                    Text("⚠️ 应用未安装在 /Applications 目录，开机自启动可能无法生效")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                HStack {
                    Text("调试日志")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("打开日志") {
                        let path = LaunchAtLoginManager.logFilePath
                        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                    }
                    .font(.caption)
                    .controlSize(.small)
                }
            }

            Section(header: Label("网页", systemImage: "globe").font(.headline)) {
                LabeledContent("DeepSeek Chat URL") {
                    Text(AppConstants.defaultChatURL)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }

                Text("当前版本仅支持 DeepSeek Chat 官方地址")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(4)
    }

    // MARK: - 外观设置

    private var appearanceTab: some View {
        Form {
            Section(header: Label("窗口大小预设", systemImage: "arrow.up.left.and.arrow.down.right").font(.headline)) {
                Picker("比例预设", selection: $windowManager.selectedPreset) {
                    ForEach(WindowPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .pickerStyle(.radioGroup)

                if windowManager.selectedPreset != .custom {
                    HStack(spacing: 4) {
                        Image(systemName: "ruler")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text(windowManager.selectedPreset.sizeDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if windowManager.selectedPreset == .custom {
                Section(header: Label("自定义窗口大小", systemImage: "slider.horizontal.3").font(.headline)) {
                    HStack {
                        Text("宽度")
                        Stepper(value: $windowManager.customWidth, in: 400...1920, step: 10) {
                            TextField("宽度", value: $windowManager.customWidth, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        Text("px")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("高度")
                        Stepper(value: $windowManager.customHeight, in: 300...1080, step: 10) {
                            TextField("高度", value: $windowManager.customHeight, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        Text("px")
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    HStack {
                        Text("快捷比例")
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("4:3")  { windowManager.customWidth = 800;  windowManager.customHeight = 600 }
                        Button("16:10"){ windowManager.customWidth = 800;  windowManager.customHeight = 500 }
                        Button("3:2")  { windowManager.customWidth = 750;  windowManager.customHeight = 500 }
                        Button("21:9") { windowManager.customWidth = 1050; windowManager.customHeight = 450 }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Section(header: Label("预览", systemImage: "eye").font(.headline)) {
                windowPreview
            }
        }
        .formStyle(.grouped)
        .padding(4)
    }

    // MARK: - 窗口预览

    private var windowPreview: some View {
        let screenSize = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1440, height: 900)
        let windowSize = windowManager.currentWindowSize
        let maxW: CGFloat = 280, maxH: CGFloat = 170
        let scale = min(maxW / screenSize.width, maxH / screenSize.height)

        return ZStack {
            // 屏幕轮廓
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.4), lineWidth: 1.5)
                .frame(width: screenSize.width * scale, height: screenSize.height * scale)

            // 窗口预览
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: windowSize.width * scale, height: windowSize.height * scale)
                .overlay(
                    VStack(spacing: 2) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                        Text("\(Int(windowSize.width)) × \(Int(windowSize.height))")
                            .font(.caption2)
                            .foregroundColor(.primary)
                    }
                )
        }
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
    }

    // MARK: - 关于

    private var aboutIcon: NSImage {
        if let icon = NSImage(named: "AppIcon") {
            return icon
        }
        return NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(nsImage: aboutIcon)
                .frame(width: 64, height: 64)

            Text(AppConstants.appName)
                .font(.title2)
                .fontWeight(.bold)

            Text("版本 \(AppConstants.version)")
                .foregroundColor(.secondary)

            Text("DeepSeek Chat 菜单栏快捷工具")
                .foregroundColor(.secondary)

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Label("在菜单栏常驻，一键打开 DeepSeek Chat", systemImage: "menubar.arrow.up.rectangle")
                Label("支持窗口大小预设（16:9 / 9:16）", systemImage: "arrow.up.left.and.arrow.down.right")
                Label("支持开机自启动配置", systemImage: "power")
                Label("支持 Intel 和 Apple Silicon", systemImage: "cpu")
            }
            .font(.callout)
            .foregroundColor(.secondary)

            Spacer()

            Text(AppConstants.copyright)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
