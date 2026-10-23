// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "GlossType",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "GlossType", targets: ["GlossTypeApp"]),
    ],
    targets: [
        // 纯逻辑，只依赖 Foundation / CoreGraphics / SQLite3；保持 Swift 5.7 可编译
        .target(
            name: "GlossTypeCore",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        // 输入法进程：InputMethodKit、候选窗、系统拼写检查、苹果翻译、设置窗
        .executableTarget(
            name: "GlossTypeApp",
            dependencies: ["GlossTypeCore"],
            linkerSettings: [
                .linkedFramework("InputMethodKit"),
                .linkedFramework("Carbon"),
            ]
        ),
        .testTarget(
            name: "GlossTypeCoreTests",
            dependencies: ["GlossTypeCore"],
            exclude: ["Fixtures"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
