import Foundation
import AppKit

// MARK: - 窗口大小预设

enum WindowPreset: String, CaseIterable, Identifiable {
    /// 16:9 横屏 - 960×540
    case landscape16x9 = "16:9 横屏"
    /// 9:16 竖屏 - 450×800
    case portrait9x16 = "9:16 竖屏"
    /// 自定义大小
    case custom = "自定义"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var baseSize: NSSize {
        switch self {
        case .landscape16x9:
            return NSSize(width: 960, height: 540)
        case .portrait9x16:
            return NSSize(width: 450, height: 800)
        case .custom:
            return NSSize(width: 800, height: 600)
        }
    }

    /// 预设的描述信息
    var sizeDescription: String {
        switch self {
        case .landscape16x9:
            return "960 × 540 像素"
        case .portrait9x16:
            return "450 × 800 像素"
        case .custom:
            return "自定义大小"
        }
    }
}

// MARK: - 窗口大小管理器

class WindowSizeManager: ObservableObject {
    static let shared = WindowSizeManager()

    /// 当前选中的预设
    @Published var selectedPreset: WindowPreset {
        didSet {
            savePreset()
            if selectedPreset != .custom {
                // 非自定义模式时，同步宽高
                customWidth = Int(selectedPreset.baseSize.width)
                customHeight = Int(selectedPreset.baseSize.height)
            }
        }
    }

    /// 自定义宽度
    @Published var customWidth: Int {
        didSet {
            if selectedPreset == .custom {
                scheduleCustomSizeSave()
            }
        }
    }

    /// 自定义高度
    @Published var customHeight: Int {
        didSet {
            if selectedPreset == .custom {
                scheduleCustomSizeSave()
            }
        }
    }

    /// 防抖任务：避免 Stepper 连续调整时频繁写入 UserDefaults
    private var pendingSave: DispatchWorkItem?

    /// 当前应该使用的窗口大小
    var currentWindowSize: NSSize {
        switch selectedPreset {
        case .custom:
            return NSSize(width: max(400, CGFloat(customWidth)),
                          height: max(300, CGFloat(customHeight)))
        default:
            return selectedPreset.baseSize
        }
    }

    private init() {
        // 读取保存的预设
        let savedPresetRaw = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKey.windowPreset)
            ?? WindowPreset.landscape16x9.rawValue
        self.selectedPreset = WindowPreset(rawValue: savedPresetRaw) ?? .landscape16x9

        // 读取自定义尺寸
        let savedWidth = UserDefaults.standard.integer(forKey: AppConstants.UserDefaultsKey.customWidth)
        self.customWidth = savedWidth > 0 ? savedWidth : 800

        let savedHeight = UserDefaults.standard.integer(forKey: AppConstants.UserDefaultsKey.customHeight)
        self.customHeight = savedHeight > 0 ? savedHeight : 600
    }

    private func savePreset() {
        UserDefaults.standard.set(selectedPreset.rawValue, forKey: AppConstants.UserDefaultsKey.windowPreset)
    }

    private func saveCustomSize() {
        UserDefaults.standard.set(customWidth, forKey: AppConstants.UserDefaultsKey.customWidth)
        UserDefaults.standard.set(customHeight, forKey: AppConstants.UserDefaultsKey.customHeight)
    }

    /// 延迟 0.4s 写入，期间的连续变更只落盘一次
    private func scheduleCustomSizeSave() {
        pendingSave?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.saveCustomSize()
        }
        pendingSave = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: task)
    }

    /// 立即落盘（应用退出前调用，避免丢失未写入的变更）
    func flushPendingSave() {
        if pendingSave != nil {
            pendingSave?.cancel()
            pendingSave = nil
            saveCustomSize()
        }
    }

    /// 应用窗口大小到指定窗口
    func applySize(to window: NSWindow?) {
        guard let window = window else { return }
        let size = currentWindowSize
        let frame = window.frame
        let newFrame = NSRect(
            x: frame.origin.x + (frame.width - size.width) / 2,
            y: frame.origin.y + (frame.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
        window.setFrame(newFrame, display: true, animate: true)
    }
}
