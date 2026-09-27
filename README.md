# DS Bar

DeepSeek Chat 菜单栏快捷工具 —— 在 macOS 菜单栏常驻，一键打开 DeepSeek Chat。

## 功能特性

- 🔄 **菜单栏常驻** — 启动后驻留在菜单栏，不占用 Dock
- 💬 **一键打开 DeepSeek Chat** — 左键点击图标即弹出网页窗口
- 🕘 **访问历史** — 自动记住上次访问的页面，下次打开直接恢复
- ⚙️ **开机自启动** — 基于 `SMAppService`，失败自动回退 AppleScript
- 📐 **窗口大小预设** — 16:9 横屏 / 9:16 竖屏 / 自定义尺寸
- 📦 **拖拽安装引导** — 未安装到 `/Applications` 时引导用户拖拽安装
- 🍎 **双架构支持** — Universal Binary（Intel x86_64 + Apple Silicon arm64）

## 系统要求

- macOS 13.0 (Ventura) 或更高版本
- Xcode Command Line Tools（`xcode-select --install`）
- 完整 Xcode **不是必需的**，构建脚本直接调用 `swiftc`

## 构建

```bash
chmod +x build.sh

./build.sh            # 构建当前架构的 .app
./build.sh universal  # 构建 Universal Binary（推荐，Intel + Apple Silicon）
./build.sh intel      # 仅 Intel (x86_64)
./build.sh arm        # 仅 Apple Silicon (arm64)
./build.sh run        # 构建并启动 .app
./build.sh clean      # 清理构建产物
```

产物位于 `dist/DSBar.app`，构建脚本会自动执行 ad-hoc 签名（`SMAppService` 需要）。

## 安装

将 `dist/DSBar.app` 拖入「应用程序」文件夹。

首次从其他位置启动时，应用会弹出**拖拽安装引导窗口**，可以直接把应用图标拖到「应用程序」文件夹上，或点击「帮我移动到应用程序文件夹」自动完成。

> 开机自启动依赖应用位于 `/Applications` 目录，请先完成安装再启用该功能。

## 使用方式

| 操作 | 说明 |
|------|------|
| 左键点击菜单栏图标 | 弹出 / 关闭 DeepSeek Chat 窗口 |
| 右键点击菜单栏图标 | 显示上下文菜单 |
| 上下文菜单 → 打开 | 与左键点击行为一致 |
| 上下文菜单 → 设置 | 打开设置面板 |
| 上下文菜单 → 关于 | 显示关于面板 |
| 上下文菜单 → 退出 | 退出应用 |

## 设置

### 窗口大小预设

| 预设 | 比例 | 尺寸 |
|------|------|------|
| 16:9 横屏 | 16:9 | 960 × 540 |
| 9:16 竖屏 | 9:16 | 450 × 800 |
| 自定义 | 任意 | 默认 800 × 600 |

自定义模式下提供快捷比例按钮：4:3、16:10、3:2、21:9。

### 开机自启动

- **macOS 13+**：使用 `SMAppService.mainApp`。若状态为 `requiresApproval`，应用会自动打开
  「系统设置 > 通用 > 登录项」，需要在该处手动允许。
- **回退方案**：`SMAppService` 失败时自动改用 AppleScript 操作登录项。

设置界面提供「打开日志」按钮，可查看完整诊断日志（`/tmp/DSBar/launchatlogin.log`）。

## 项目结构

```
ds-bar/
├── Assets/
│   ├── icon.png                     # 图标源文件（1024×1024，背景透明）
├── Sources/
│   └── DSBar/
│       ├── DSBarApp.swift           # 应用入口
│       ├── AppConstants.swift       # 全局常量（版本号、尺寸、URL、UserDefaults keys）
│       ├── AppDelegate.swift        # 应用代理：状态栏、Popover、窗口、安装引导
│       ├── WebViewManager.swift     # WKWebView 工厂 + 导航代理 + 错误页
│       ├── WindowSizeManager.swift  # 窗口尺寸预设与持久化（带防抖）
│       ├── LaunchAtLoginManager.swift # 开机自启动（SMAppService + AppleScript 回退）
│       ├── NavigationHistoryManager.swift # 访问历史持久化
│       ├── Logger.swift             # 日志工具（控制台 + 文件，含大小上限）
│       ├── WindowDelegate.swift     # 通用窗口关闭回调委托
│       ├── SettingsView.swift       # 设置界面（通用 / 外观 / 关于）
│       ├── InstallGuideView.swift   # 拖拽安装引导窗口
│       └── Resources/
│           ├── Info.plist           # 应用配置（唯一来源）
│           ├── AppIcon.icns         # 由 Assets/icon.png 自动生成
│           └── statusbar*.png       # 由 Assets/icon.png 自动生成
├── Package.swift                    # 仅供 IDE 索引，不参与构建
├── build.sh                         # 构建脚本
└── README.md
```

> `Sources/DSBar/Resources/` 下的图标产物由 `build.sh` 从 `Assets/icon.png` 自动生成，
> 且仅在源文件更新时重新生成。


## 技术栈

- **语言**: Swift 5.8
- **UI**: SwiftUI + AppKit
- **网页渲染**: WebKit（`WKWebView`）
- **最低部署目标**: macOS 13.0
- **构建**: 直接调用 `swiftc` + `lipo` + `codesign`（无需 Xcode 工程）

## 安全说明

- WebView 导航限制在 `deepseek.com` 及其子域名，外部链接交给默认浏览器打开
- 未开启 ATS 例外（`NSAllowsArbitraryLoads`），仅访问 HTTPS 站点

## License

MIT License

Copyright © 2026 hy
