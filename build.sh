#!/bin/bash
# ============================================================================
# DS Bar 构建脚本
#
# 用法:
#   ./build.sh              - 构建并打包 .app (当前架构)
#   ./build.sh universal    - 构建 Universal Binary (.app 包含 Intel + Apple Silicon)
#   ./build.sh intel        - 仅构建 Intel (x86_64)
#   ./build.sh arm          - 仅构建 Apple Silicon (arm64)
#   ./build.sh run          - 构建并运行
#   ./build.sh clean        - 清理构建
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

BUILD_DIR="$SCRIPT_DIR/.build"
OUTPUT_DIR="$SCRIPT_DIR/dist"
APP_NAME="DSBar.app"
# SDK 路径：优先 xcrun，fallback 到 CLT 默认路径
SDK_PATH=$(xcrun --show-sdk-path 2>/dev/null || echo "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk")
DEPLOYMENT_TARGET="13.0"

SOURCES=(
    "Sources/DSBar/DSBarApp.swift"
    "Sources/DSBar/AppConstants.swift"
    "Sources/DSBar/AppDelegate.swift"
    "Sources/DSBar/Logger.swift"
    "Sources/DSBar/WindowSizeManager.swift"
    "Sources/DSBar/LaunchAtLoginManager.swift"
    "Sources/DSBar/NavigationHistoryManager.swift"
    "Sources/DSBar/WebViewManager.swift"
    "Sources/DSBar/SettingsView.swift"
    "Sources/DSBar/InstallGuideView.swift"
    "Sources/DSBar/WindowDelegate.swift"
)

# 图标源文件
ICON_SOURCE="$SCRIPT_DIR/Assets/icon.png"
ICON_OUTPUT_DIR="$SCRIPT_DIR/Sources/DSBar/Resources"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
log_error()   { echo -e "${RED}[✗]${NC} $1"; }

check_swift() {
    if ! command -v swiftc &> /dev/null; then
        log_error "Swift 编译器未安装"
        log_info "请安装 Xcode Command Line Tools: xcode-select --install"
        exit 1
    fi
    log_info "Swift 版本: $(swift --version 2>&1 | head -1)"
}

# 从原始图标生成 .icns 和状态栏图标（仅在源文件存在且比产物新时生成）
generate_icons() {
    if [ ! -f "$ICON_SOURCE" ]; then
        log_warn "图标源文件不存在: ${ICON_SOURCE}，跳过图标生成"
        return
    fi

    local icns_out="$ICON_OUTPUT_DIR/AppIcon.icns"
    local sb_out="$ICON_OUTPUT_DIR/statusbar.png"
    local sb2x_out="$ICON_OUTPUT_DIR/statusbar@2x.png"

    # 检查产物是否已是最新
    if [ -f "$icns_out" ] && [ -f "$sb_out" ] && [ -f "$sb2x_out" ] && \
       [ "$ICON_SOURCE" -ot "$icns_out" ]; then
        return
    fi

    log_info "从 $ICON_SOURCE 生成图标资源..."

    # 生成 iconset
    local iconset_dir="$BUILD_DIR/icon.iconset"
    mkdir -p "$iconset_dir"
    sips -z 16 16     "$ICON_SOURCE" --out "$iconset_dir/icon_16x16.png" >/dev/null 2>&1
    sips -z 32 32     "$ICON_SOURCE" --out "$iconset_dir/icon_16x16@2x.png" >/dev/null 2>&1
    sips -z 32 32     "$ICON_SOURCE" --out "$iconset_dir/icon_32x32.png" >/dev/null 2>&1
    sips -z 64 64     "$ICON_SOURCE" --out "$iconset_dir/icon_32x32@2x.png" >/dev/null 2>&1
    sips -z 128 128   "$ICON_SOURCE" --out "$iconset_dir/icon_128x128.png" >/dev/null 2>&1
    sips -z 256 256   "$ICON_SOURCE" --out "$iconset_dir/icon_128x128@2x.png" >/dev/null 2>&1
    sips -z 256 256   "$ICON_SOURCE" --out "$iconset_dir/icon_256x256.png" >/dev/null 2>&1
    sips -z 512 512   "$ICON_SOURCE" --out "$iconset_dir/icon_256x256@2x.png" >/dev/null 2>&1
    sips -z 512 512   "$ICON_SOURCE" --out "$iconset_dir/icon_512x512.png" >/dev/null 2>&1
    sips -z 1024 1024 "$ICON_SOURCE" --out "$iconset_dir/icon_512x512@2x.png" >/dev/null 2>&1

    # 转为 .icns
    iconutil -c icns "$iconset_dir" -o "$icns_out" 2>/dev/null

    # 生成状态栏图标
    sips -z 18 18 "$ICON_SOURCE" --out "$sb_out" >/dev/null 2>&1
    sips -z 36 36 "$ICON_SOURCE" --out "$sb2x_out" >/dev/null 2>&1

    # 清理临时 iconset
    rm -rf "$iconset_dir"

    log_success "图标资源生成完成"
}

do_clean() {
    log_info "清理构建目录..."
    rm -rf "$BUILD_DIR"
    rm -rf "$OUTPUT_DIR"
    log_success "清理完成"
}

# 编译单个架构
compile_arch() {
    local arch="$1"
    local output="$2"

    log_info "编译 $arch..."

    swiftc \
        -target "${arch}-apple-macosx${DEPLOYMENT_TARGET}" \
        -sdk "$SDK_PATH" \
        -framework Cocoa \
        -framework WebKit \
        -framework ServiceManagement \
        -parse-as-library \
        -module-cache-path "$BUILD_DIR/modulecache_${arch}" \
        -o "$output" \
        "${SOURCES[@]}" \
        2>&1

    if [ ! -f "$output" ]; then
        log_error "编译失败: $arch"
        exit 1
    fi

    log_success "编译完成: $arch"
}

# 创建 .app 包
create_app_bundle() {
    local executable="$1"
    local arch_label="$2"

    rm -rf "$OUTPUT_DIR/$APP_NAME"
    mkdir -p "$OUTPUT_DIR/$APP_NAME/Contents/MacOS"
    mkdir -p "$OUTPUT_DIR/$APP_NAME/Contents/Resources"

    cp "$executable" "$OUTPUT_DIR/$APP_NAME/Contents/MacOS/DSBar"

    # 复制图标资源到 .app 包
    cp "$SCRIPT_DIR/Sources/DSBar/Resources/AppIcon.icns" "$OUTPUT_DIR/$APP_NAME/Contents/Resources/AppIcon.icns"
    cp "$SCRIPT_DIR/Sources/DSBar/Resources/statusbar.png" "$OUTPUT_DIR/$APP_NAME/Contents/Resources/statusbar.png"
    cp "$SCRIPT_DIR/Sources/DSBar/Resources/statusbar@2x.png" "$OUTPUT_DIR/$APP_NAME/Contents/Resources/statusbar@2x.png"

    # Info.plist 以 Sources/DSBar/Resources/Info.plist 为唯一来源
    cp "$SCRIPT_DIR/Sources/DSBar/Resources/Info.plist" "$OUTPUT_DIR/$APP_NAME/Contents/Info.plist"

    echo -n "APPL????" > "$OUTPUT_DIR/$APP_NAME/Contents/PkgInfo"

    # 对 .app 进行 ad-hoc 签名，SMAppService 要求应用有签名
    log_info "对 .app 进行 ad-hoc 签名..."
    codesign --force --deep --sign - "$OUTPUT_DIR/$APP_NAME" 2>&1 || {
        log_warn "ad-hoc 签名失败，开机自启动功能可能受影响"
    }

    log_success ".app 包已创建: $OUTPUT_DIR/$APP_NAME ($arch_label)"

    local file_size=$(du -sh "$OUTPUT_DIR/$APP_NAME" | cut -f1)
    local supported_archs=$(lipo -archs "$OUTPUT_DIR/$APP_NAME/Contents/MacOS/DSBar" 2>/dev/null || echo "unknown")
    log_info "大小: $file_size | 架构: $supported_archs"
}

main() {
    check_swift

    local command="${1:-build}"

    mkdir -p "$BUILD_DIR"

    generate_icons

    case "$command" in
        clean)
            do_clean
            ;;
        build)
            local current_arch=$(uname -m)
            compile_arch "$current_arch" "$BUILD_DIR/DSBar"
            create_app_bundle "$BUILD_DIR/DSBar" "$current_arch"
            ;;
        intel)
            compile_arch "x86_64" "$BUILD_DIR/DSBar_x86_64"
            create_app_bundle "$BUILD_DIR/DSBar_x86_64" "x86_64"
            ;;
        arm)
            compile_arch "arm64" "$BUILD_DIR/DSBar_arm64"
            create_app_bundle "$BUILD_DIR/DSBar_arm64" "arm64"
            ;;
        universal)
            compile_arch "x86_64" "$BUILD_DIR/DSBar_x86_64"
            compile_arch "arm64" "$BUILD_DIR/DSBar_arm64"
            log_info "创建 Universal Binary..."
            lipo -create "$BUILD_DIR/DSBar_x86_64" "$BUILD_DIR/DSBar_arm64" -output "$BUILD_DIR/DSBar_universal"
            log_success "Universal Binary 创建完成"
            create_app_bundle "$BUILD_DIR/DSBar_universal" "Universal (x86_64 + arm64)"
            ;;
        run)
            local current_arch=$(uname -m)
            compile_arch "$current_arch" "$BUILD_DIR/DSBar"
            create_app_bundle "$BUILD_DIR/DSBar" "$current_arch"
            log_info "启动应用..."
            open "$OUTPUT_DIR/$APP_NAME"
            ;;
        *)
            log_error "未知命令: $command"
            echo ""
            echo "用法: $0 [command]"
            echo ""
            echo "命令:"
            echo "  build       - 构建并打包 .app (当前架构, 默认)"
            echo "  universal   - 构建 Universal Binary (Intel + Apple Silicon)"
            echo "  intel       - 仅构建 Intel (x86_64)"
            echo "  arm         - 仅构建 Apple Silicon (arm64)"
            echo "  run         - 构建并直接运行"
            echo "  clean       - 清理构建"
            exit 1
            ;;
    esac
}

main "$@"
