import Foundation
import ServiceManagement
import AppKit

/// 开机自启动管理器
///
/// macOS 13+: 优先使用 SMAppService API，失败则 fallback 到 AppleScript
/// macOS 12-:  使用 AppleScript 操作 Login Items
enum LaunchAtLoginManager {

    // MARK: - Public API

    /// 当前是否已启用开机自启动
    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            log("isEnabled check: SMAppService.mainApp.status = \(statusDescription(status))")
            // requiresApproval 也视为"已注册但待批准"，UI 上显示为开启
            return status == .enabled || status == .requiresApproval
        } else {
            let result = isLoginItemEnabled()
            log("isEnabled check (legacy): \(result)")
            return result
        }
    }

    /// 当前状态的描述文本（用于 UI 展示）
    static var statusDescription: String {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            switch status {
            case .enabled: return "已启用"
            case .requiresApproval: return "已注册，等待系统批准"
            case .notRegistered: return "未启用"
            case .notFound: return "未找到（应用可能未正确安装）"
            default: return "未知状态"
            }
        } else {
            return isLoginItemEnabled() ? "已启用" : "未启用"
        }
    }

    /// 设置开机自启动
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> String? {
        log("setEnabled(\(enabled)) called")
        log("  bundlePath: \(Bundle.main.bundlePath)")
        log("  bundleIdentifier: \(Bundle.main.bundleIdentifier ?? "nil")")
        log("  isProperlyInstalled: \(isProperlyInstalled)")

        if #available(macOS 13.0, *) {
            return setEnabledModern(enabled)
        } else {
            return setEnabledLegacy(enabled)
        }
    }

    /// 应用是否位于 /Applications 目录下
    static var isProperlyInstalled: Bool {
        Bundle.main.bundlePath.hasPrefix("/Applications/")
    }

    /// 打开系统设置中的「登录项」页面（macOS 13+）
    static func openLoginItemsSettings() {
        if #available(macOS 13.0, *) {
            // macOS 13 Ventura: 系统设置 > 通用 > 登录项
            let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!
            NSWorkspace.shared.open(url)
        } else {
            // macOS 12: 系统偏好设置 > 用户与群组 > 登录项
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.users")!
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - macOS 13+ (SMAppService)

    @available(macOS 13.0, *)
    private static func setEnabledModern(_ enabled: Bool) -> String? {
        let service = SMAppService.mainApp
        log("  SMAppService.mainApp.status = \(statusDescription(service.status))")

        if enabled {
            // --- 注册开机自启动 ---
            // 先尝试 SMAppService
            var smAppServiceSucceeded = false

            do {
                try service.register()
                smAppServiceSucceeded = true
                log("  SMAppService.mainApp.register() succeeded")
            } catch {
                log("  SMAppService.mainApp.register() failed: \(error.localizedDescription)")
                log("  Error domain: \((error as NSError).domain), code: \((error as NSError).code)")
            }

            // 检查注册后的实际状态
            let newStatus = service.status
            log("  After register, status = \(statusDescription(newStatus))")

            switch newStatus {
            case .enabled:
                log("  Status is .enabled, registration fully successful")
                return nil

            case .requiresApproval:
                log("  Status is .requiresApproval, need user approval in System Settings")
                // 注册成功但需要用户在系统设置中批准
                // 自动打开系统设置引导用户批准
                DispatchQueue.main.async {
                    openLoginItemsSettings()
                }
                return "请在\"系统设置 > 通用 > 登录项\"中允许 \(AppConstants.appName)"

            case .notFound:
                log("  Status is .notFound, app signature or location issue")
                // SMAppService 找不到应用，可能是签名或位置问题，fallback 到 legacy
                return setEnabledLegacy(enabled)

            default:
                // register 抛了异常，且状态不是上述情况
                if !smAppServiceSucceeded {
                    log("  SMAppService register failed, trying legacy fallback")
                    return setEnabledLegacy(enabled)
                }
                log("  Unexpected status after register: \(statusDescription(newStatus))")
                return setEnabledLegacy(enabled)
            }

        } else {
            // --- 取消开机自启动 ---
            // 先尝试 SMAppService unregister
            do {
                try service.unregister()
                log("  SMAppService.mainApp.unregister() succeeded")
            } catch {
                log("  SMAppService.mainApp.unregister() failed: \(error.localizedDescription)")
                log("  Trying legacy fallback for unregister")
            }

            // 同时也尝试从 legacy Login Items 中删除，确保清理干净
            let legacyResult = setEnabledLegacy(false)
            let newStatus = service.status
            log("  After unregister, SMAppService status = \(statusDescription(newStatus))")

            return legacyResult
        }
    }

    @available(macOS 13.0, *)
    private static func statusDescription(_ status: SMAppService.Status) -> String {
        switch status {
        case .notRegistered: return "notRegistered"
        case .enabled: return "enabled"
        case .requiresApproval: return "requiresApproval"
        case .notFound: return "notFound"
        default: return "unknown(\(status.rawValue))"
        }
    }

    // MARK: - macOS 12 / Fallback (AppleScript Login Items)

    private static func setEnabledLegacy(_ enabled: Bool) -> String? {
        let appName = AppConstants.appName
        let appPath = Bundle.main.bundlePath

        log("  Using AppleScript Login Items method")
        log("  appName: \(appName), appPath: \(appPath)")

        let script: String
        if enabled {
            script = """
            tell application "System Events"
                try
                    if not (login item "\(appName)" exists) then
                        make login item at end with properties {{name:"\(appName)", path:"\(appPath)", hidden:false}}
                    end if
                on error errMsg
                    return errMsg
                end try
            end tell
            return "ok"
            """
        } else {
            script = """
            tell application "System Events"
                try
                    if (login item "\(appName)" exists) then
                        delete login item "\(appName)"
                    end if
                on error errMsg
                    return errMsg
                end try
            end tell
            return "ok"
            """
        }

        let result = runAppleScript(script)
        log("  AppleScript result: \(result)")

        if result == "ok" {
            // 验证是否真的添加成功
            let verified = isLoginItemEnabled()
            log("  Verification: isLoginItemEnabled = \(verified)")
            if enabled && !verified {
                return "开机自启动注册未生效，请检查\"系统设置 > 通用 > 登录项\""
            }
            return nil
        }
        return result.isEmpty ? "开机自启动设置失败" : "开机自启动设置失败: \(result)"
    }

    private static func isLoginItemEnabled() -> Bool {
        let script = """
        tell application "System Events"
            try
                return (login item "\(AppConstants.appName)" exists) as text
            on error
                return "false"
            end try
        end tell
        """
        return runAppleScript(script) == "true"
    }

    // MARK: - AppleScript Runner

    private static func runAppleScript(_ source: String) -> String {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        let result = script?.executeAndReturnError(&error)

        if let error = error {
            let errMsg = error[NSAppleScript.errorMessage] as? String ?? "unknown error"
            let errNum = error[NSAppleScript.errorNumber] as? Int ?? -1
            log("  AppleScript error: \(errMsg) (number: \(errNum))")
            return errMsg
        }

        return result?.stringValue ?? ""
    }

    // MARK: - Logging

    private static let logCategory = "LaunchAtLogin"

    private static func log(_ message: String) {
        Logger.info(message, category: logCategory)
    }

    /// 获取日志文件路径，供设置界面显示
    static var logFilePath: String {
        Logger.logFilePath(category: logCategory)
    }
}
