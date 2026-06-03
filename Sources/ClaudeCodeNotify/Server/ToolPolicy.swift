import Foundation

/// Espelha a decisão do Claude Code: "essa chamada faria o Claude PERGUNTAR ao usuário?".
/// Se sim → o app mostra o card. Se não → `defer` (o Claude segue o fluxo nativo).
///
/// É uma aproximação das regras do Claude. Erro seguro por construção: se aqui der
/// "não pergunta" mas o Claude perguntaria, cai no prompt nativo (nunca libera silencioso).
enum ToolPolicy {
    /// Matcher do hook: TODAS as ferramentas (o app decide caso a caso).
    static let matcher = "*"

    /// Read-only: o Claude libera dentro do projeto, mas pergunta pra caminho fora dele.
    static let readOnlyTools: Set<String> = ["Read", "Grep", "Glob", "LS", "NotebookRead"]

    /// O Claude nunca pergunta por essas.
    static let neverAskTools: Set<String> = [
        "TodoWrite", "Task", "WebSearch", "BashOutput", "KillShell", "KillBash", "ExitPlanMode"
    ]

    /// Edição de arquivo — auto-aprovada no modo acceptEdits.
    static let editTools: Set<String> = ["Edit", "Write", "MultiEdit", "NotebookEdit"]

    static func wouldAsk(_ r: PermissionRequest, permissions: ClaudePermissions) -> Bool {
        switch r.permissionMode {
        case "bypassPermissions", "plan":
            return false // Claude resolve sozinho (libera tudo / bloqueia edits no plan)
        default:
            break
        }

        // Regras explícitas do Claude → ele decide sem perguntar.
        if permissions.matchesDeny(r) { return false }
        if permissions.matchesAllow(r) { return false }
        // Regra "ask" explícita → pergunta.
        if permissions.matchesAsk(r) { return true }

        if neverAskTools.contains(r.toolName) { return false }

        if readOnlyTools.contains(r.toolName) {
            return !r.targetInsideProject() // só pergunta pra alvo fora do projeto
        }

        if r.permissionMode == "acceptEdits", editTools.contains(r.toolName) {
            return false
        }

        // Bash, Edit/Write (modo default), WebFetch, MCP, etc. → o Claude pergunta.
        return true
    }
}
