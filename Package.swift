// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeCodeNotify",
    platforms: [
        .macOS(.v13) // SMAppService.mainApp exige macOS 13+
    ],
    targets: [
        .executableTarget(
            name: "ClaudeCodeNotify",
            path: "Sources/ClaudeCodeNotify"
        )
    ]
)
