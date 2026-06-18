// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeCodeNotify",
    platforms: [
        // Universal (Intel + Apple Silicon), Monterey+. macOS 13-only APIs
        // (SMAppService, ImageRenderer, .formStyle) are gated behind #available in code.
        .macOS(.v12)
    ],
    targets: [
        .executableTarget(
            name: "ClaudeCodeNotify",
            path: "Sources/ClaudeCodeNotify"
        ),
        .testTarget(
            name: "ClaudeCodeNotifyTests",
            dependencies: ["ClaudeCodeNotify"],
            path: "Tests/ClaudeCodeNotifyTests"
        )
    ]
)
