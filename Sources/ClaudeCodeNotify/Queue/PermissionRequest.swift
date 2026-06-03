import Foundation

/// Um pedido de permissão enfileirado. Identidade = tool_use_id (chave de dedup/fila).
struct PermissionRequest: Identifiable {
    let id: String              // tool_use_id
    let sessionID: String?
    let cwd: String?
    let toolName: String
    let permissionMode: String? // default | acceptEdits | plan | bypassPermissions
    let command: String?        // Bash
    let toolDescription: String?// Bash (texto pronto)
    let filePath: String?       // Edit/Write/MultiEdit/NotebookEdit
    let content: String?        // Write
    let path: String?           // Read/LS/Glob/Grep (campo "path"/"file_path")

    init(payload: HookPayload) {
        self.id = payload.toolUseID ?? UUID().uuidString
        self.sessionID = payload.sessionID
        self.cwd = payload.cwd
        self.toolName = payload.toolName ?? "?"
        self.permissionMode = payload.permissionMode
        self.command = payload.toolInput?.command
        self.toolDescription = payload.toolInput?.description
        self.filePath = payload.toolInput?.filePath
        self.content = payload.toolInput?.content
        self.path = payload.toolInput?.filePath ?? payload.toolInput?.raw["path"]?.stringValue
    }

    /// Nome curto do projeto (basename do cwd) pro header/fila.
    var projectName: String {
        guard let cwd, !cwd.isEmpty else { return "?" }
        return (cwd as NSString).lastPathComponent
    }

    /// O alvo (caminho) está dentro da pasta do projeto (cwd)? Caminhos relativos contam como dentro.
    func targetInsideProject() -> Bool {
        guard let path, !path.isEmpty else { return true } // sem caminho conhecido → trata como dentro
        guard path.hasPrefix("/") else { return true }     // relativo → dentro do cwd
        guard let cwd, !cwd.isEmpty else { return false }
        let normCwd = cwd.hasSuffix("/") ? cwd : cwd + "/"
        return path == cwd || path.hasPrefix(normCwd)
    }
}

/// Resultado do clique no card.
enum CardDecision {
    case allow
    case allowAlways(pattern: String)  // "não perguntar de novo" (allowlist entra no passo 6)
    case deny(reason: String)
}
