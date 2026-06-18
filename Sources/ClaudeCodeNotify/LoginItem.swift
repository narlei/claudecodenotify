import Foundation
import ServiceManagement

/// "Open at login".
/// - macOS 13+: `SMAppService.mainApp` (integrates with System Settings › Login Items).
///   Only works for the registered .app; in a dev binary it may fail — handled with a log.
/// - macOS 12: `SMAppService` doesn't exist, so we fall back to a LaunchAgent plist in
///   `~/Library/LaunchAgents` (`RunAtLoad`), preserving the feature on Monterey.
enum LoginItem {
    private static let label = "com.narlei.ClaudeCodeNotify"

    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    static func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            // Clean up any LaunchAgent left behind by a prior macOS 12 install so an
            // OS upgrade can't double-launch the app (SMAppService + LaunchAgent).
            removeLaunchAgent()
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                NSLog("ClaudeCodeNotify: SMAppService failed: \(error)")
            }
        } else {
            enabled ? writeLaunchAgent() : removeLaunchAgent()
        }
    }

    // MARK: - macOS 12 LaunchAgent fallback

    private static var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    private static func writeLaunchAgent() {
        // Launch the executable inside the running .app bundle directly (LSUIElement,
        // so no Dock icon). Falls back to argv[0] when there's no bundle (dev binary).
        let execPath = Bundle.main.executablePath ?? CommandLine.arguments.first ?? ""
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [execPath],
            "RunAtLoad": true,
        ]
        do {
            try FileManager.default.createDirectory(
                at: launchAgentURL.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: launchAgentURL)
        } catch {
            NSLog("ClaudeCodeNotify: LaunchAgent write failed: \(error)")
        }
    }

    private static func removeLaunchAgent() {
        if FileManager.default.fileExists(atPath: launchAgentURL.path) {
            try? FileManager.default.removeItem(at: launchAgentURL)
        }
    }
}
