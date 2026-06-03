import Foundation

/// Quais ferramentas o app gerencia (mostra card). As demais → `defer` (motor nativo do
/// Claude Code decide). Mantemos o conjunto curado de write/exec pra não round-tripar todo
/// Read/Grep (risco #2 do SPEC: latência). O matcher instalado no hook usa o mesmo conjunto;
/// o `defer` aqui é a rede de segurança caso algo fora dele chegue.
enum ToolPolicy {
    static let managedTools: Set<String> = [
        "Bash", "Edit", "Write", "MultiEdit", "NotebookEdit"
    ]

    /// String de matcher pro settings.json (formato "Bash|Edit|...").
    static var matcher: String {
        managedTools.sorted().joined(separator: "|")
    }

    static func isManaged(_ toolName: String?) -> Bool {
        guard let toolName else { return false }
        return managedTools.contains(toolName)
    }
}
