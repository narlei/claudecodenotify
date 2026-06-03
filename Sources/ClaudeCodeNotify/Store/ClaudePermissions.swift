import Foundation

/// Lê as regras de permissão do próprio Claude Code (`permissions.allow/deny/ask`) pra
/// espelhar "o Claude perguntaria?". Faz merge de: global (~/.claude/settings.json) +
/// projeto (<cwd>/.claude/settings.json) + local (<cwd>/.claude/settings.local.json).
/// Enterprise/managed fica de fora no v1.
struct ClaudePermissions {
    let allow: [String]
    let deny: [String]
    let ask: [String]

    static func load(cwd: String?) -> ClaudePermissions {
        var allow: [String] = [], deny: [String] = [], ask: [String] = []

        func ingest(_ url: URL) {
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let p = json["permissions"] as? [String: Any] else { return }
            allow += (p["allow"] as? [String]) ?? []
            deny  += (p["deny"]  as? [String]) ?? []
            ask   += (p["ask"]   as? [String]) ?? []
        }

        ingest(AppPaths.claudeSettings) // global
        if let cwd, !cwd.isEmpty {
            let dir = URL(fileURLWithPath: cwd).appendingPathComponent(".claude")
            ingest(dir.appendingPathComponent("settings.json"))        // projeto
            ingest(dir.appendingPathComponent("settings.local.json"))  // local
        }
        return ClaudePermissions(allow: allow, deny: deny, ask: ask)
    }

    func matchesAllow(_ r: PermissionRequest) -> Bool { allow.contains { Allowlist.pattern($0, matches: r) } }
    func matchesDeny(_ r: PermissionRequest)  -> Bool { deny.contains  { Allowlist.pattern($0, matches: r) } }
    func matchesAsk(_ r: PermissionRequest)   -> Bool { ask.contains   { Allowlist.pattern($0, matches: r) } }
}
