import Foundation

/// Decisão devolvida ao hook (ver SPEC §3). `defer` = comporta-se como se o hook não existisse.
enum Decision: String {
    case allow
    case deny
    case `defer`

    /// Monta o JSON exato esperado pelo Claude Code no stdout do hook.
    func responseJSON(reason: String) -> Data {
        let payload: [String: Any] = [
            "hookSpecificOutput": [
                "hookEventName": "PreToolUse",
                "permissionDecision": rawValue,
                "permissionDecisionReason": reason
            ]
        ]
        return (try? JSONSerialization.data(withJSONObject: payload)) ?? Data("{}".utf8)
    }
}
