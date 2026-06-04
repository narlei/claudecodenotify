import Foundation

/// Instala/desinstala a integração: escreve o bridge.sh (notificador) e registra os hooks
/// `Notification` + `Stop` no ~/.claude/settings.json, com BACKUP antes e dedup (preserva
/// outros hooks do usuário).
enum HookInstaller {

    /// Eventos que o app escuta (só notifica — não bloqueia nada).
    static let managedEvents = ["Notification", "Stop"]

    /// Template do bridge.sh (fonte única). NÃO bloqueia: POST fire-and-forget pro app.
    /// chmod 700 (executável + só o dono lê o token). Passa $TERM_PROGRAM pra saber o terminal.
    private static let bridgeTemplate = """
    #!/bin/bash
    # ClaudeCodeNotify bridge (notificador) — gerado pelo app. NÃO editar à mão.
    # Avisa o app que o Claude pediu algo/terminou. Fire-and-forget; nunca bloqueia.
    TOKEN="__CCNOTIFY_TOKEN__"
    PORT_FILE="__CCNOTIFY_PORT_FILE__"
    input="$(cat)"
    PORT="$(cat "$PORT_FILE" 2>/dev/null)"
    [ -z "$PORT" ] && exit 0
    printf '%s' "$input" | curl -s --max-time 3 \\
      -H "X-CCNotify-Token: $TOKEN" \\
      -H "X-CCNotify-Term: ${TERM_PROGRAM:-}" \\
      -H "Content-Type: application/json" \\
      --data-binary @- "http://127.0.0.1:$PORT/notify" >/dev/null 2>&1
    exit 0
    """

    // MARK: - Estado

    static var isInstalled: Bool {
        guard let hooks = readSettings()?["hooks"] as? [String: Any] else { return false }
        return managedEvents.contains { event in
            (hooks[event] as? [[String: Any]])?.contains(where: entryReferencesBridge) ?? false
        }
    }

    // MARK: - Install / Uninstall

    static func install(token: String) throws {
        try writeBridgeScript(token: token)
        var settings = readSettings() ?? [:]
        backupSettingsIfPresent()

        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        for event in managedEvents {
            var groups = hooks[event] as? [[String: Any]] ?? []
            groups.removeAll(where: entryReferencesBridge)               // dedup
            groups.append(["hooks": [["type": "command", "command": AppPaths.bridgeScript.path]]])
            hooks[event] = groups
        }
        settings["hooks"] = hooks
        try writeSettings(settings)
    }

    @discardableResult
    static func writeBridgeOnly(token: String) throws -> String {
        try writeBridgeScript(token: token)
        return AppPaths.bridgeScript.path
    }

    static func uninstall() throws {
        guard var settings = readSettings(), var hooks = settings["hooks"] as? [String: Any] else { return }
        backupSettingsIfPresent()
        for event in managedEvents {
            guard var groups = hooks[event] as? [[String: Any]] else { continue }
            groups.removeAll(where: entryReferencesBridge)
            if groups.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = groups }
        }
        if hooks.isEmpty { settings.removeValue(forKey: "hooks") } else { settings["hooks"] = hooks }
        try writeSettings(settings)
    }

    // MARK: - bridge.sh

    private static func writeBridgeScript(token: String) throws {
        _ = try AppPaths.ensureSupportDirectory()
        try FileManager.default.createDirectory(at: AppPaths.bridgeDirectory, withIntermediateDirectories: true)
        let script = bridgeTemplate
            .replacingOccurrences(of: "__CCNOTIFY_TOKEN__", with: token)
            .replacingOccurrences(of: "__CCNOTIFY_PORT_FILE__", with: AppPaths.portFile.path)
        try script.write(to: AppPaths.bridgeScript, atomically: true, encoding: .utf8)
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
        let data = try JSONSerialization.data(withJSONObject: settings,
                                              options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: AppPaths.claudeSettings, options: .atomic)
    }

    private static func backupSettingsIfPresent() {
        let src = AppPaths.claudeSettings
        guard FileManager.default.fileExists(atPath: src.path) else { return }
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backup = src.deletingLastPathComponent().appendingPathComponent("settings.json.bak.\(stamp)")
        try? FileManager.default.copyItem(at: src, to: backup)
    }

    private static func entryReferencesBridge(_ group: [String: Any]) -> Bool {
        guard let inner = group["hooks"] as? [[String: Any]] else { return false }
        return inner.contains { ($0["command"] as? String) == AppPaths.bridgeScript.path }
    }
}
