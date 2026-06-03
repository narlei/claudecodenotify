import Foundation

/// Um pedido de permissão enfileirado. Identidade = tool_use_id (chave de dedup/fila).
struct PermissionRequest: Identifiable {
    let id: String              // tool_use_id
    let sessionID: String?
    let cwd: String?
    let toolName: String
    let command: String?        // Bash
    let toolDescription: String?// Bash (texto pronto)
    let filePath: String?       // Edit/Write/MultiEdit/NotebookEdit
    let content: String?        // Write

    init(payload: HookPayload) {
        self.id = payload.toolUseID ?? UUID().uuidString
        self.sessionID = payload.sessionID
        self.cwd = payload.cwd
        self.toolName = payload.toolName ?? "?"
        self.command = payload.toolInput?.command
        self.toolDescription = payload.toolInput?.description
        self.filePath = payload.toolInput?.filePath
        self.content = payload.toolInput?.content
    }

    /// Nome curto do projeto (basename do cwd) pro header/fila.
    var projectName: String {
        guard let cwd, !cwd.isEmpty else { return "?" }
        return (cwd as NSString).lastPathComponent
    }
}

/// Resultado do clique no card.
enum CardDecision {
    case allow
    case allowAlways(pattern: String)  // "não perguntar de novo" (allowlist entra no passo 6)
    case deny(reason: String)
}
