import Foundation

/// Disk locations used by the app. Everything lives in
/// ~/Library/Application Support/ClaudeCodeNotify/
enum AppPaths {
    static let bundleIdentifier = "com.narlei.ClaudeCodeNotify"

    /// Home base. In production it's the real home; `CCNOTIFY_HOME` allows sandboxing in tests
    /// (FileManager.homeDirectoryForCurrentUser ignores $HOME, so we have our own env).
    static var home: URL {
        if let override = ProcessInfo.processInfo.environment["CCNOTIFY_HOME"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    /// ~/Library/Application Support/ClaudeCodeNotify/
    static var supportDirectory: URL {
        home.appendingPathComponent("Library/Application Support/ClaudeCodeNotify", isDirectory: true)
    }

    /// secret token + allowlist seed flag
    static var configFile: URL { supportDirectory.appendingPathComponent("config.json") }

    /// current ephemeral port; rewritten at each launch and read by bridge.sh at runtime
    static var portFile: URL { supportDirectory.appendingPathComponent("port") }

    /// user preferences (duration + sound per notification type)
    static var preferencesFile: URL { supportDirectory.appendingPathComponent("preferences.json") }

    /// account profiles metadata (names, emojis, hotkeys — never credentials)
    static var profilesFile: URL { supportDirectory.appendingPathComponent("profiles.json") }

    /// Bridge.sh directory. No spaces in path intentionally: Claude Code executes the hook
    /// `command` by splitting on spaces, so "Application Support" (with space) fails.
    /// The store (config/port/allowlist) lives in Application Support; only bridge lives here.
    static var bridgeDirectory: URL { home.appendingPathComponent(".ccnotify", isDirectory: true) }

    /// Installed bridge.sh (referenced by hook in settings.json) — path without spaces.
    static var bridgeScript: URL { bridgeDirectory.appendingPathComponent("bridge.sh") }

    /// ~/.claude/settings.json (global user settings)
    static var claudeSettings: URL {
        home.appendingPathComponent(".claude/settings.json")
    }

    /// ~/.claude.json (Claude Code CLI state, including oauthAccount identity)
    static var claudeConfig: URL {
        home.appendingPathComponent(".claude.json")
    }

    /// Ensures support directory exists. Returns the URL.
    @discardableResult
    static func ensureSupportDirectory() throws -> URL {
        let dir = supportDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
