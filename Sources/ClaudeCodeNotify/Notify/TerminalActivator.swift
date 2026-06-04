import AppKit

/// Traz pra frente o terminal onde o Claude está rodando. Usa $TERM_PROGRAM (vindo do bridge)
/// pra achar o app; se não reconhecer, cai no app que estava em foco quando a notificação chegou.
enum TerminalActivator {
    /// TERM_PROGRAM → bundle id.
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

    static func activate(termProgram: String?, fallback: NSRunningApplication?) {
        // .activateIgnoringOtherApps é necessário: nosso app está em foco (capturou o teclado),
        // então sem essa opção o macOS ignora a troca pro terminal.
        let opts: NSApplication.ActivationOptions = [.activateIgnoringOtherApps]
        if let term = termProgram, let bundleID = bundleByTerm[term],
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            app.activate(options: opts)
            return
        }
        fallback?.activate(options: opts)
    }
}
