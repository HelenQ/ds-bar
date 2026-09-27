import SwiftUI
import UniformTypeIdentifiers
import Darwin

// MARK: - 安装引导窗口

struct InstallGuideView: View {
    let bundlePath: String
    @Environment(\.dismiss) private var dismiss

    @State private var isTargeted = false
    @State private var isMoving = false
    @State private var moveError: String?

    private let appIconSize: CGFloat = 80
    private let folderIconSize: CGFloat = 80

    var body: some View {
        VStack(spacing: 0) {
            // 标题区
            headerSection

            Divider()
                .padding(.horizontal, 24)

            // 拖拽区
            dragSection
                .padding(.vertical, 24)

            Divider()
                .padding(.horizontal, 24)

            // 按钮区
            buttonSection
                .padding(.vertical, 16)
        }
        .frame(width: 460)
    }

    // MARK: - 标题

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("将 \(AppConstants.appName) 拖到应用程序文件夹")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.top, 20)

            Text("拖拽左侧图标到右侧文件夹，或点击下方按钮自动完成")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
        }
    }

    // MARK: - 拖拽区

    private var dragSection: some View {
        HStack(spacing: 0) {
            // 左侧：当前 App（可拖拽）
            appSourceView

            // 中间：箭头
            arrowView

            // 右侧：Applications 文件夹（可接收拖放）
            appTargetView
        }
        .padding(.horizontal, 24)
    }

    private var appSourceView: some View {
        VStack(spacing: 10) {
            // App 图标 - 可拖拽
            DraggableAppIcon(path: bundlePath, size: appIconSize)

            Text(AppConstants.appName)
                .font(.callout)
                .fontWeight(.medium)

            Text(currentLocationAbbrev)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity)
    }

    private var arrowView: some View {
        VStack {
            Spacer()
            Image(systemName: "arrow.right")
                .font(.title2)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(width: 60)
    }

    private var appTargetView: some View {
        VStack(spacing: 10) {
            // Applications 文件夹 - 可接收拖放
            DropTargetFolder(
                size: folderIconSize,
                isTargeted: $isTargeted,
                onDrop: handleDrop
            )

            Text("应用程序")
                .font(.callout)
                .fontWeight(.medium)

            Text("/Applications")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 按钮区

    private var buttonSection: some View {
        VStack(spacing: 8) {
            if let error = moveError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
            }

            HStack(spacing: 12) {
                Button("稍后再说") {
                    closeWindow()
                }
                .keyboardShortcut(.cancelAction)

                Button(action: autoMove) {
                    if isMoving {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 16, height: 16)
                    }
                    Text(isMoving ? "移动中..." : "帮我移动到应用程序文件夹")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isMoving)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - 计算

    private var currentLocationAbbrev: String {
        let path = (bundlePath as NSString).abbreviatingWithTildeInPath
        return path
    }

    // MARK: - 操作

    private func handleDrop() {
        autoMove()
    }

    private func autoMove() {
        isMoving = true
        moveError = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let sourceURL = URL(fileURLWithPath: bundlePath)
            let fileName = sourceURL.lastPathComponent
            let destURL = URL(fileURLWithPath: "/Applications").appendingPathComponent(fileName)

            // 如果目标已存在先删除
            if FileManager.default.fileExists(atPath: destURL.path) {
                try? FileManager.default.removeItem(at: destURL)
            }

            do {
                try FileManager.default.copyItem(at: sourceURL, to: destURL)

                // 程序化拷贝会保留 com.apple.quarantine，而该属性会触发
                // App Translocation —— 副本即使位于 /Applications，也仍会以
                // /private/var/folders/.../AppTranslocation/... 路径运行，
                // 导致安装检测持续判定「未安装」，引导窗口反复弹出。
                // 只有 Finder 拖动才会打上「禁止 translocate」标志，故此处直接清除。
                InstallGuideView.removeQuarantine(at: destURL)

                DispatchQueue.main.async {
                    // 启动 /Applications 下的副本
                    let config = NSWorkspace.OpenConfiguration()
                    config.activates = true
                    NSWorkspace.shared.openApplication(at: destURL, configuration: config) { _, error in
                        DispatchQueue.main.async {
                            isMoving = false
                            if let error = error {
                                print("InstallGuide: Failed to launch from /Applications: \(error)")
                                moveError = "启动失败：\(error.localizedDescription)，请手动拖拽安装"
                            } else {
                                // 启动成功后再退出当前实例
                                NSApp.terminate(nil)
                            }
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isMoving = false
                    moveError = "移动失败：\(error.localizedDescription)"
                }
            }
        }
    }

    /// 递归清除隔离属性，等价于 `xattr -dr com.apple.quarantine`
    private static func removeQuarantine(at url: URL) {
        let keys = ["com.apple.quarantine", "com.apple.provenance"]
        var targets = [url]
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) {
            targets.append(contentsOf: enumerator.compactMap { $0 as? URL })
        }
        for target in targets {
            for key in keys {
                removexattr(target.path, key, 0)
            }
        }
    }

    private func closeWindow() {
        dismiss()
    }
}

// MARK: - 可拖拽的 App 图标

struct DraggableAppIcon: View {
    let path: String
    let size: CGFloat

    var body: some View {
        Image(nsImage: appIcon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .onDrag {
                NSItemProvider(object: URL(fileURLWithPath: path) as NSURL)
            }
    }

    private var appIcon: NSImage {
        // 优先使用 app bundle 内置图标
        if let icon = NSImage(named: "AppIcon") {
            icon.size = NSSize(width: size, height: size)
            return icon
        }
        // fallback: 从文件路径获取
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: size, height: size)
        return icon
    }
}

// MARK: - 可接收拖放的文件夹

struct DropTargetFolder: View {
    let size: CGFloat
    @Binding var isTargeted: Bool
    let onDrop: () -> Void

    var body: some View {
        ZStack {
            // 文件夹图标
            Image(nsImage: folderIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)

            // 拖放高亮
            if isTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .frame(width: size + 16, height: size + 16)
                    .shadow(color: .accentColor.opacity(0.3), radius: 8)
            }
        }
        .frame(width: size + 16, height: size + 16)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private var folderIcon: NSImage {
        let icon = NSWorkspace.shared.icon(forFile: "/Applications")
        icon.size = NSSize(width: size, height: size)
        return icon
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        _ = provider.loadObject(ofClass: URL.self) { url, error in
            if let url = url, url.pathExtension == "app" {
                DispatchQueue.main.async {
                    onDrop()
                }
            }
        }

        return true
    }
}
