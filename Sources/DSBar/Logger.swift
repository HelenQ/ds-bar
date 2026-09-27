import Foundation

/// 轻量日志工具，支持 print + 文件写入
///
/// 使用方式：
///   Logger.shared.info("message", category: "LaunchAtLogin")
///   Logger.shared.error("failed", category: "LaunchAtLogin")
///
/// 日志文件位于 /tmp/DSBar/ 目录下，按 category 分文件
enum Logger {

    static let shared = Logger.self

    /// 日志级别
    enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warn = "WARN"
        case error = "ERROR"
    }

    // MARK: - Public API

    static func debug(_ message: String, category: String = "General") {
        log(level: .debug, message: message, category: category)
    }

    static func info(_ message: String, category: String = "General") {
        log(level: .info, message: message, category: category)
    }

    static func warn(_ message: String, category: String = "General") {
        log(level: .warn, message: message, category: category)
    }

    static func error(_ message: String, category: String = "General") {
        log(level: .error, message: message, category: category)
    }

    /// 获取日志文件路径
    static func logFilePath(category: String = "General") -> String {
        logDir + "/\(category.lowercased()).log"
    }

    /// 日志目录
    static var logDir: String {
        NSTemporaryDirectory() + "DSBar"
    }

    // MARK: - Internal

    private static func log(level: Level, message: String, category: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let line = "[\(category) \(timestamp)] [\(level.rawValue)] \(message)"

        // 输出到控制台
        print(line)

        // 写入文件
        writeToLog(line + "\n", category: category)
    }

    private static func writeToLog(_ text: String, category: String) {
        let dir = logDir
        let path = logFilePath(category: category)

        // 确保目录存在
        if !FileManager.default.fileExists(atPath: dir) {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }

        guard let data = text.data(using: .utf8) else { return }

        // 追加写入
        if FileManager.default.fileExists(atPath: path) {
            // 检查日志大小，超过 1MB 则截断
            if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
               let size = attrs[.size] as? UInt64, size > 1_048_576 {
                try? FileManager.default.removeItem(atPath: path)
            }

            if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}
