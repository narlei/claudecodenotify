import XCTest
@testable import ClaudeCodeNotify

/// Base para testes que tocam o disco: aponta `CCNOTIFY_HOME` para um diretório
/// temporário único por teste, então `AppPaths.*` nunca encosta no ~/.claude real.
/// Ver memória `test-with-ccnotify-home`.
class SandboxedTestCase: XCTestCase {
    private(set) var home: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        home = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("ccnotify-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        setenv("CCNOTIFY_HOME", home.path, 1)
        XCTAssertEqual(AppPaths.home.path, home.path, "sandbox de CCNOTIFY_HOME não aplicou")
    }

    override func tearDownWithError() throws {
        unsetenv("CCNOTIFY_HOME")
        if let home { try? FileManager.default.removeItem(at: home) }
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    /// Lê o ~/.claude/settings.json sandboxado como dicionário (nil se não existir).
    func readSettings() -> [String: Any]? {
        guard let data = try? Data(contentsOf: AppPaths.claudeSettings) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// Escreve um settings.json sandboxado a partir de um dicionário.
    func writeSettings(_ dict: [String: Any]) throws {
        let dir = AppPaths.claudeSettings.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted])
        try data.write(to: AppPaths.claudeSettings)
    }

    /// Grupos de hooks registrados para um evento (ex.: "Notification").
    func hookGroups(for event: String) -> [[String: Any]] {
        let hooks = readSettings()?["hooks"] as? [String: Any]
        return (hooks?[event] as? [[String: Any]]) ?? []
    }

    /// Quantas entradas referenciam o bridge.sh do app, em todos os grupos do evento.
    func bridgeEntryCount(for event: String) -> Int {
        hookGroups(for: event).reduce(0) { acc, group in
            let inner = (group["hooks"] as? [[String: Any]]) ?? []
            return acc + inner.filter { ($0["command"] as? String) == AppPaths.bridgeScript.path }.count
        }
    }
}
