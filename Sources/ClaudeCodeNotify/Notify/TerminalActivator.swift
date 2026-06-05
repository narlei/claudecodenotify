import AppKit

/// Discovers the GUI app where Claude is running (Ghostty, iTerm, Terminal, Cursor, VS Code…)
/// and brings it to front. Main strategy: the ancestor PIDs chain from bridge — the
/// first ancestor that is a "real" app (`.regular`) is the host. This distinguishes
/// Cursor from VS Code and finds the exact instance, without a fixed map.
enum TerminalActivator {
    /// Fallback by $TERM_PROGRAM if PID chain doesn't resolve.
    private static let bundleByTerm: [String: String] = [
        "ghostty": "com.mitchellh.ghostty",
        "iTerm.app": "com.googlecode.iterm2",
        "Apple_Terminal": "com.apple.Terminal",
        "vscode": "com.microsoft.VSCode",
        "WezTerm": "com.github.wez.wezterm",
        "Hyper": "co.zeit.hyper",
        "WarpTerminal": "dev.warp.Warp-Stable",
        "kitty": "net.kovidgoyal.kitty",
        "tabby": "org.tabby",
        "alacritty": "org.alacritty"
    ]

    /// Resolves the host app from the PID chain (+ fallback by TERM_PROGRAM).
    static func resolveHost(pids: [Int32], termProgram: String?) -> NSRunningApplication? {
        for pid in pids {
            if let app = NSRunningApplication(processIdentifier: pid), app.activationPolicy == .regular {
                return app
            }
        }
        if let term = termProgram, let bundleID = bundleByTerm[term] {
            return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
        }
        return nil
    }

    static func activate(_ app: NSRunningApplication?) {
        // .activateIgnoringOtherApps: our app is in focus (captured keyboard), so
        // without this macOS ignores the switch to terminal.
        app?.activate(options: [.activateIgnoringOtherApps])
    }

    /// Confirms the resolved host is exactly the frontmost app. No fallback by
    /// bundle ID: in case of doubt, the app should notify to avoid hiding an event.
    static func isFocused(_ hostApp: NSRunningApplication?,
                          frontmostApp: NSRunningApplication?) -> Bool {
        guard let hostApp, let frontmostApp else { return false }
        return hostApp.processIdentifier == frontmostApp.processIdentifier
    }
}
