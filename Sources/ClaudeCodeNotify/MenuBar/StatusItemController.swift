import AppKit

/// Item de menu bar: ícone de sino + menu (conectar/desconectar o Claude Code, abrir no login, sair).
@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let token: String

    init(token: String) {
        self.token = token
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bell", accessibilityDescription: "ClaudeCodeNotify")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()
    }

    private func rebuildMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()

        let connected = HookInstaller.isInstalled
        let header = menu.addItem(withTitle: connected ? "Claude Code: connected" : "Claude Code: disconnected",
                                  action: nil, keyEquivalent: "")
        header.isEnabled = false

        menu.addItem(.separator())
        if connected {
            menu.addItem(withTitle: "Disconnect Claude Code", action: #selector(disconnect), keyEquivalent: "").target = self
        } else {
            menu.addItem(withTitle: "Connect Claude Code", action: #selector(connect), keyEquivalent: "").target = self
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",").target = self
        let login = menu.addItem(withTitle: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q").target = self
    }

    @objc private func openPreferences() {
        PreferencesWindowController.shared.show()
    }

    @objc private func toggleLogin() {
        LoginItem.setEnabled(!LoginItem.isEnabled)
        rebuildMenu()
    }

    @objc private func connect() {
        do {
            try HookInstaller.install(token: token)
            notify("Claude Code connected", "Hooks were installed in ~/.claude/settings.json (a backup was created).")
        } catch {
            notify("Failed to connect", "\(error)")
        }
        rebuildMenu()
    }

    @objc private func disconnect() {
        do {
            try HookInstaller.uninstall()
            notify("Claude Code disconnected", "Hooks were removed from ~/.claude/settings.json (a backup was created).")
        } catch {
            notify("Failed to disconnect", "\(error)")
        }
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func notify(_ title: String, _ body: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.alertStyle = .informational
        // Não-ativante: mostra sem roubar foco indefinidamente.
        alert.runModal()
    }
}

extension StatusItemController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu() // reflete o estado real do settings.json a cada abertura
    }
}
