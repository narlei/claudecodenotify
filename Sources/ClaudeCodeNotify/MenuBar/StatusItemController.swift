import AppKit

/// Item de menu bar: ícone de sino + menu (conectar/desconectar o Claude Code, abrir no login, sair).
@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private var config: Config
    private var token: String { config.token }

    init(config: Config) {
        self.config = config
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            // Glifo monocromático (template) no padrão dos ícones nativos da menu bar.
            button.image = IconRenderer.menuBarImage()
                ?? NSImage(systemSymbolName: "bell", accessibilityDescription: "ClaudeCodeNotify")
            button.image?.isTemplate = true
            button.image?.accessibilityDescription = "ClaudeCodeNotify"
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
        header.image = statusDot(connected ? .systemGreen : .systemRed)

        menu.addItem(.separator())
        if connected {
            menu.addItem(withTitle: "Disconnect Claude Code", action: #selector(disconnect), keyEquivalent: "").target = self
        } else {
            menu.addItem(withTitle: "Connect Claude Code", action: #selector(connect), keyEquivalent: "").target = self
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "Welcome…", action: #selector(openWelcome), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",").target = self
        let login = menu.addItem(withTitle: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off

        menu.addItem(.separator())
        let updateTitle = Updater.shared.hasNewVersion ? "Check for Updates… (New version available!)" : "Check for Updates…"
        let updateItem = menu.addItem(withTitle: updateTitle, action: #selector(checkUpdates), keyEquivalent: "")
        updateItem.target = self
        if Updater.shared.hasNewVersion { updateItem.image = statusDot(.systemBlue) }

        if !config.donationHidden {
            menu.addItem(.separator())
            menu.addItem(buildSupportItem())
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q").target = self
    }

    /// Submenu de doação ("pague um café"). Some quando o usuário marca "já doei".
    private func buildSupportItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Support ClaudeCodeNotify ☕", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        if let koFi = SupportLinks.koFi {
            let i = sub.addItem(withTitle: "Buy me a coffee (Ko-fi)", action: #selector(openKoFi), keyEquivalent: "")
            i.target = self; i.representedObject = koFi
        }
        if let payPal = SupportLinks.payPal {
            let i = sub.addItem(withTitle: "Donate via PayPal", action: #selector(openPayPal), keyEquivalent: "")
            i.target = self; i.representedObject = payPal
        }
        sub.addItem(withTitle: "Copy Pix key (\(SupportLinks.pixKey))", action: #selector(copyPix), keyEquivalent: "").target = self
        sub.addItem(.separator())
        sub.addItem(withTitle: "I already donated — hide this", action: #selector(hideDonation), keyEquivalent: "").target = self
        item.submenu = sub
        return item
    }

    /// Bolinha colorida de status pro item do menu (verde = conectado, vermelho = não).
    private func statusDot(_ color: NSColor) -> NSImage? {
        let cfg = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        let img = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)
        img?.isTemplate = false
        return img
    }

    @objc private func openKoFi(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL { SupportLinks.open(url) }
    }

    @objc private func openPayPal(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL { SupportLinks.open(url) }
    }

    @objc private func copyPix() {
        SupportLinks.copyPixKey()
    }

    @objc private func hideDonation() {
        config.hideDonation()
        rebuildMenu()
    }

    @objc private func openWelcome() {
        OnboardingWindowController.shared.show(token: token)
    }

    @objc private func openPreferences() {
        PreferencesWindowController.shared.show()
    }

    @objc private func checkUpdates() {
        Updater.shared.checkForUpdates(explicit: true)
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
        Task {
            let hadUpdate = Updater.shared.hasNewVersion
            await Updater.shared.silentCheck()
            if !hadUpdate && Updater.shared.hasNewVersion {
                await MainActor.run { self.rebuildMenu() }
            }
        }
        rebuildMenu() // reflete o estado real do settings.json a cada abertura
    }
}
