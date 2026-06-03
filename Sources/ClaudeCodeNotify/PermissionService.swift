import AppKit

/// Liga o servidor HTTP à decisão: aplica a política (defer p/ não-gerenciadas / bypass),
/// e, pras gerenciadas, mostra o card e resolve no clique. Escreve a porta efêmera no
/// portFile a cada launch (lido pelo bridge.sh em runtime).
@MainActor
final class PermissionService {
    private(set) var config: Config
    private var server: LocalHTTPServer?
    private let queue = RequestQueue()
    private let allowlist = Allowlist()

    /// Notifica mudança de porta (pra UI/menu, se quiser exibir).
    var onPortChange: ((UInt16) -> Void)?
    /// Repassa o tamanho da fila (pro ícone da menu bar — passo 7).
    var onQueueCountChange: ((Int) -> Void)? {
        didSet { queue.onCountChange = onQueueCountChange }
    }

    init(config: Config) {
        self.config = config
        allowlist.seedIfNeeded(config: &self.config)
    }

    func start() {
        let server = LocalHTTPServer(token: config.token) { [weak self] payload, respond in
            // Handler roda na queue do servidor; decisão de UI vai pra main.
            Task { @MainActor in
                self?.decide(payload, respond: respond)
            }
        }
        server.onReady = { port in
            Self.writePortFile(port)
            Task { @MainActor in self.onPortChange?(port) }
        }
        do {
            try server.start()
            self.server = server
        } catch {
            NSLog("ClaudeCodeNotify: não foi possível iniciar o servidor: \(error)")
        }
    }

    func stop() {
        server?.stop()
        server = nil
    }

    // MARK: - Decisão

    private func decide(_ payload: HookPayload, respond: @escaping (Decision, String) -> Void) {
        // bypassPermissions: o usuário já optou por não ser perguntado → defer.
        if payload.permissionMode == "bypassPermissions" {
            respond(.defer, "bypassPermissions -> defer")
            return
        }
        // Ferramenta não gerenciada → defer (motor nativo decide).
        guard ToolPolicy.isManaged(payload.toolName) else {
            respond(.defer, "ferramenta não gerenciada -> defer")
            return
        }

        let request = PermissionRequest(payload: payload)
        // Log discreto: sem o comando/conteúdo (evita vazar dado sensível no log do sistema).
        NSLog("ClaudeCodeNotify: recebido tool=\(request.toolName) proj=\(request.projectName) id=\(request.id)")

        // Allowlist própria: casa → allow na hora, sem card (medir latência — risco #2).
        if allowlist.matches(request) {
            NSLog("ClaudeCodeNotify: decisão=allow (allowlist) id=\(request.id)")
            respond(.allow, "ClaudeCodeNotify: liberado pela allowlist")
            return
        }

        // Gerenciada e não liberada: enfileira e mostra o card.
        NSLog("ClaudeCodeNotify: card id=\(request.id)")
        queue.enqueue(request) { [weak self] decision in
            switch decision {
            case .allow:
                NSLog("ClaudeCodeNotify: decisão=allow id=\(request.id)")
                respond(.allow, "ClaudeCodeNotify: usuário aprovou")
            case .allowAlways(let pattern):
                NSLog("ClaudeCodeNotify: decisão=allow+allowlist id=\(request.id)")
                self?.allowlist.add(pattern)
                respond(.allow, "ClaudeCodeNotify: aprovado e adicionado à allowlist (\(pattern))")
            case .deny(let reason):
                NSLog("ClaudeCodeNotify: decisão=deny id=\(request.id)")
                let msg = reason.isEmpty ? "ClaudeCodeNotify: usuário negou" : reason
                respond(.deny, msg)
            }
        }
    }

    // MARK: - Port file

    private static func writePortFile(_ port: UInt16) {
        _ = try? AppPaths.ensureSupportDirectory()
        let url = AppPaths.portFile
        try? "\(port)\n".data(using: .utf8)?.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
