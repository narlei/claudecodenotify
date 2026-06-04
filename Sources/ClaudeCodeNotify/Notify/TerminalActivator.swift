import AppKit

/// Descobre o app GUI onde o Claude está rodando (Ghostty, iTerm, Terminal, Cursor, VS Code…)
/// e o traz pra frente. Estratégia principal: a cadeia de PIDs ancestrais do bridge — o
/// primeiro ancestral que é um app "de verdade" (`.regular`) é o host. Isso distingue
/// Cursor de VS Code e acha a instância exata, sem mapa fixo.
enum TerminalActivator {
    /// Fallback por $TERM_PROGRAM, caso a cadeia de PIDs não resolva.
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

    /// Resolve o app host a partir da cadeia de PIDs (+ fallback por TERM_PROGRAM).
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
        // .activateIgnoringOtherApps: nosso app está em foco (capturou o teclado), então
        // sem isso o macOS ignora a troca pro terminal.
        app?.activate(options: [.activateIgnoringOtherApps])
    }
}
