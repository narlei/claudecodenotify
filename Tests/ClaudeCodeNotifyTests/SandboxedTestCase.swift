import XCTest
@testable import ClaudeCodeNotify

/// Base for tests that touch disk: points `CCNOTIFY_HOME` to a unique temporary directory
/// per test, so `AppPaths.*` never touches the real ~/.claude.
/// See memory `test-with-ccnotify-home`.
class SandboxedTestCase: XCTestCase {
    private(set) var home: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        home = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("ccnotify-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        setenv("CCNOTIFY_HOME", home.path, 1)
        XCTAssertEqual(AppPaths.home.path, home.path, "CCNOTIFY_HOME sandbox didn't apply")
    }

    override func tearDownWithError() throws {
        unsetenv("CCNOTIFY_HOME")
        if let home { try? FileManager.default.removeItem(at: home) }
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    /// Reads sandboxed ~/.claude/settings.json as dictionary (nil if not found).
    func readSettings() -> [String: Any]? {
        guard let data = try? Data(contentsOf: AppPaths.claudeSettings) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// Writes sandboxed settings.json from a dictionary.
    func writeSettings(_ dict: [String: Any]) throws {
        let dir = AppPaths.claudeSettings.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted])
        try data.write(to: AppPaths.claudeSettings)
    }

    /// Hook groups registered for an event (e.g. "Notification").
    func hookGroups(for event: String) -> [[String: Any]] {
        let hooks = readSettings()?["hooks"] as? [String: Any]
        return (hooks?[event] as? [[String: Any]]) ?? []
    }

    /// Count entries referencing app's bridge.sh, across all groups of the event.
    func bridgeEntryCount(for event: String) -> Int {
        hookGroups(for: event).reduce(0) { acc, group in
            let inner = (group["hooks"] as? [[String: Any]]) ?? []
            return acc + inner.filter { ($0["command"] as? String) == AppPaths.bridgeScript.path }.count
        }
    }
}
