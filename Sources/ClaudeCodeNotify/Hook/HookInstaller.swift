import Foundation

/// Instala/desinstala a integração com o Claude Code:
///  - escreve o bridge.sh (token embutido, lê a porta em runtime) com permissão restrita;
///  - faz merge da entrada PreToolUse no ~/.claude/settings.json, com BACKUP antes e dedup
///    (o usuário pode ter outros hooks — preservamos tudo).
enum HookInstaller {

    enum InstallError: Error { case settingsNotObject }

    /// Template do bridge.sh (fonte única). `__CCNOTIFY_TOKEN__`/`__CCNOTIFY_PORT_FILE__`
    /// são substituídos no install. chmod 700 (executável + só dono lê o token).
    private static let bridgeTemplate = """
    #!/bin/bash
    # ClaudeCodeNotify bridge — gerado automaticamente pelo app. NÃO editar à mão.
    # Encaminha o input do hook PreToolUse pro app (POST bloqueante) e devolve a decisão.
    # CRÍTICO: em QUALQUER falha emite JSON `defer` explícito. Nunca confia em exit code.
    TOKEN="__CCNOTIFY_TOKEN__"
    PORT_FILE="__CCNOTIFY_PORT_FILE__"
    DEFER='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"defer","permissionDecisionReason":"ClaudeCodeNotify offline -> defer"}}'

    input="$(cat)"
    PORT="$(cat "$PORT_FILE" 2>/dev/null)"
    if [ -z "$PORT" ]; then
      printf '%s' "$DEFER"
      exit 0
    fi

    resp="$(printf '%s' "$input" | curl -s --max-time 600 \\
              -H "X-CCNotify-Token: $TOKEN" \\
              -H "Content-Type: application/json" \\
              --data-binary @- "http://127.0.0.1:$PORT/decision")"

    if [ -z "$resp" ]; then
      printf '%s' "$DEFER"
    else
      printf '%s' "$resp"
    fi

    """

    // MARK: - Estado

    static var isInstalled: Bool {
        guard let settings = readSettings(),
              let hooks = settings["hooks"] as? [String: Any],
              let pre = hooks["PreToolUse"] as? [[String: Any]] else { return false }
        return pre.contains { entryReferencesBridge($0) }
    }

    // MARK: - Install

    static func install(token: String) throws {
        try writeBridgeScript(token: token)

        var settings = readSettings() ?? [:]
        backupSettingsIfPresent()

        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        var pre = hooks["PreToolUse"] as? [[String: Any]] ?? []

        // Remove entradas nossas antigas (dedup) e acrescenta a atual.
        pre.removeAll { entryReferencesBridge($0) }
        pre.append([
            "matcher": ToolPolicy.matcher,
            "hooks": [
                ["type": "command", "command": AppPaths.bridgeScript.path]
            ]
        ])

        hooks["PreToolUse"] = pre
        settings["hooks"] = hooks
        try writeSettings(settings)
    }

    // MARK: - Uninstall

    static func uninstall() throws {
        guard var settings = readSettings(),
              var hooks = settings["hooks"] as? [String: Any],
              var pre = hooks["PreToolUse"] as? [[String: Any]] else { return }

        backupSettingsIfPresent()
        pre.removeAll { entryReferencesBridge($0) }

        if pre.isEmpty {
            hooks.removeValue(forKey: "PreToolUse")
        } else {
            hooks["PreToolUse"] = pre
        }
        if hooks.isEmpty {
            settings.removeValue(forKey: "hooks")
        } else {
            settings["hooks"] = hooks
        }
        try writeSettings(settings)
    }

    // MARK: - bridge.sh

    /// Escreve só o bridge.sh (sem tocar no settings.json). Útil pra teste isolado com um
    /// .claude/settings.json LOCAL de projeto. Retorna o caminho do bridge.
    @discardableResult
    static func writeBridgeOnly(token: String) throws -> String {
        try writeBridgeScript(token: token)
        return AppPaths.bridgeScript.path
    }

    private static func writeBridgeScript(token: String) throws {
        _ = try AppPaths.ensureSupportDirectory()
        try FileManager.default.createDirectory(at: AppPaths.bridgeDirectory, withIntermediateDirectories: true)
        let script = bridgeTemplate
            .replacingOccurrences(of: "__CCNOTIFY_TOKEN__", with: token)
            .replacingOccurrences(of: "__CCNOTIFY_PORT_FILE__", with: AppPaths.portFile.path)
        try script.write(to: AppPaths.bridgeScript, atomically: true, encoding: .utf8)
        // 700: executável (hook type:command precisa) + só o dono lê o token.
        try FileManager.default.setAttributes([.posixPermissions: 0o700],
                                              ofItemAtPath: AppPaths.bridgeScript.path)
    }

    // MARK: - settings.json

    private static func readSettings() -> [String: Any]? {
        guard let data = try? Data(contentsOf: AppPaths.claudeSettings) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func writeSettings(_ settings: [String: Any]) throws {
        let dir = AppPaths.claudeSettings.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: AppPaths.claudeSettings, options: .atomic)
    }

    /// Backup com timestamp, só se o arquivo existir.
    private static func backupSettingsIfPresent() {
        let src = AppPaths.claudeSettings
        guard FileManager.default.fileExists(atPath: src.path) else { return }
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backup = src.deletingLastPathComponent()
            .appendingPathComponent("settings.json.bak.\(stamp)")
        try? FileManager.default.copyItem(at: src, to: backup)
    }

    /// True se a entrada PreToolUse tem algum hook apontando pro nosso bridge.sh.
    private static func entryReferencesBridge(_ entry: [String: Any]) -> Bool {
        guard let inner = entry["hooks"] as? [[String: Any]] else { return false }
        let bridgePath = AppPaths.bridgeScript.path
        return inner.contains { ($0["command"] as? String) == bridgePath }
    }
}
