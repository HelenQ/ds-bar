// swift-tools-version: 5.8
//
// 说明：本文件仅供 IDE / 编辑器索引源码使用，不参与实际构建。
// 实际构建请使用 ./build.sh（直接调用 swiftc，不依赖完整 Xcode）。
//
import PackageDescription

let package = Package(
    name: "DSBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DSBar",
            path: "Sources/DSBar",
            exclude: ["Resources"],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
