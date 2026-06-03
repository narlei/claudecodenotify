import Foundation

/// Allowlist própria (store em allowlist.json). Padrões no estilo Claude Code:
///   - "Bash"                 → qualquer uso da ferramenta
///   - "Bash(npm run test:*)" → comando começa com "npm run test"
///   - "Edit(/path/dir/*)"    → arquivo dentro de /path/dir
/// Importa `permissions.allow` do ~/.claude/settings.json UMA vez (seed); depois independente.
final class Allowlist {
    private(set) var patterns: [String]

    init() {
        self.patterns = Self.load()
    }

    // MARK: - Matching

    func matches(_ request: PermissionRequest) -> Bool {
        patterns.contains { Self.pattern($0, matches: request) }
    }

    static func pattern(_ pattern: String, matches request: PermissionRequest) -> Bool {
        let (tool, inner) = parse(pattern)
        guard tool == request.toolName else { return false }
        guard let inner, !inner.isEmpty else { return true } // só o nome da ferramenta

        switch request.toolName {
        case "Bash":
            guard let command = request.command else { return false }
            let prefix = stripWildcard(inner)
            return command == prefix || command.hasPrefix(prefix)
        default: // Edit/Write/MultiEdit/NotebookEdit → casa por caminho/pasta
            guard let path = request.filePath else { return false }
            let base = stripWildcard(inner)
            return path == base || path.hasPrefix(base)
        }
    }

    /// "Bash(npm run test:*)" → ("Bash", "npm run test:*"); "Read" → ("Read", nil)
    private static func parse(_ pattern: String) -> (tool: String, inner: String?) {
        guard let open = pattern.firstIndex(of: "("), pattern.hasSuffix(")") else {
            return (pattern, nil)
        }
        let tool = String(pattern[pattern.startIndex..<open])
        let inner = String(pattern[pattern.index(after: open)..<pattern.index(before: pattern.endIndex)])
        return (tool, inner)
    }

    /// Remove sufixos curinga comuns: ":*", "/*", "*".
    private static func stripWildcard(_ s: String) -> String {
        var v = s
        if v.hasSuffix(":*") { v.removeLast(2) }
        else if v.hasSuffix("/*") { v.removeLast(1) } // mantém a "/" final como separador de pasta
        else if v.hasSuffix("*") { v.removeLast() }
        return v
    }

    // MARK: - Mutação

    func add(_ pattern: String) {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !patterns.contains(trimmed) else { return }
        patterns.append(trimmed)
        save()
    }

    func remove(_ pattern: String) {
        patterns.removeAll { $0 == pattern }
        save()
    }

    // MARK: - Seed (uma vez)

    /// Importa permissions.allow do settings.json se ainda não semeado. Atualiza a flag no config.
    func seedIfNeeded(config: inout Config) {
        guard !config.allowlistSeeded else { return }
        if let data = try? Data(contentsOf: AppPaths.claudeSettings),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let permissions = json["permissions"] as? [String: Any],
           let allow = permissions["allow"] as? [String] {
            for p in allow { add(p) }
            NSLog("ClaudeCodeNotify: allowlist semeada com \(allow.count) padrões de permissions.allow")
        }
        config.allowlistSeeded = true
        config.save()
    }

    // MARK: - Persistência

    private static func load() -> [String] {
        guard let data = try? Data(contentsOf: AppPaths.allowlistFile),
              let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return arr
    }

    private func save() {
        _ = try? AppPaths.ensureSupportDirectory()
        guard let data = try? JSONEncoder().encode(patterns) else { return }
        try? data.write(to: AppPaths.allowlistFile, options: .atomic)
    }
}
