import AppKit

/// Item de menu bar: ícone de status + menu de ações (conectar/desconectar o Claude Code,
/// card de teste, sair). O ícone de status/fila evolui no passo 7.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let token: String

    private var queueCount = 0

    init(token: String) {
        self.token = token
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        updateBadge(count: 0)

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()
    }

    /// Reflete o tamanho da fila no ícone (badge numérico quando há pedidos pendentes).
    func updateBadge(count: Int) {
        queueCount = count
        guard let button = statusItem.button else { return }
        let symbol = count > 0 ? "bell.badge.fill" : "bell"
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "ClaudeCodeNotify")
        button.image?.isTemplate = true
        button.title = count > 0 ? " \(count)" : ""
    }

    private func rebuildMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()

        let connected = HookInstaller.isInstalled
        let header = menu.addItem(withTitle: connected ? "Claude Code: conectado" : "Claude Code: desconectado",
                                  action: nil, keyEquivalent: "")
        header.isEnabled = false

        menu.addItem(.separator())
        if connected {
            menu.addItem(withTitle: "Desconectar Claude Code", action: #selector(disconnect), keyEquivalent: "").target = self
        } else {
            menu.addItem(withTitle: "Conectar Claude Code", action: #selector(connect), keyEquivalent: "").target = self
        }

        if connected, queueCount > 0 {
            let q = menu.addItem(withTitle: "\(queueCount) pedido(s) na fila", action: nil, keyEquivalent: "")
            q.isEnabled = false
        }

        menu.addItem(.separator())
        let login = menu.addItem(withTitle: "Abrir no login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off

        menu.addItem(.separator())
        menu.addItem(withTitle: "Sair", action: #selector(quit), keyEquivalent: "q").target = self
    }

    @objc private func toggleLogin() {
        LoginItem.setEnabled(!LoginItem.isEnabled)
        rebuildMenu()
    }

    @objc private func connect() {
        do {
            try HookInstaller.install(token: token)
            notify("Claude Code conectado", "O hook foi instalado no ~/.claude/settings.json (backup criado).")
        } catch {
            notify("Falha ao conectar", "\(error)")
        }
        rebuildMenu()
    }

    @objc private func disconnect() {
        do {
            try HookInstaller.uninstall()
            notify("Claude Code desconectado", "O hook foi removido do ~/.claude/settings.json (backup criado).")
        } catch {
            notify("Falha ao desconectar", "\(error)")
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
