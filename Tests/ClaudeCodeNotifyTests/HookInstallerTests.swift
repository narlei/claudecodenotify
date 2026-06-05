import XCTest
@testable import ClaudeCodeNotify

final class HookInstallerTests: SandboxedTestCase {

    // MARK: - install

    func testInstallRegistersBridgeForAllManagedEvents() throws {
        try HookInstaller.install(token: "tkn")

        for event in HookInstaller.managedEvents {
            XCTAssertEqual(bridgeEntryCount(for: event), 1,
                           "expected exactly 1 bridge entry in \(event)")
        }
        XCTAssertTrue(HookInstaller.isInstalled)
    }

    func testInstallWritesBridgeScriptWith0700AndSubstitutions() throws {
        try HookInstaller.install(token: "secret-token-123")

        let script = try String(contentsOf: AppPaths.bridgeScript, encoding: .utf8)
        XCTAssertTrue(script.contains("TOKEN=\"secret-token-123\""), "token not substituted")
        XCTAssertTrue(script.contains(AppPaths.portFile.path), "port file not substituted")
        XCTAssertFalse(script.contains("__CCNOTIFY_TOKEN__"), "token placeholder remained in script")
        XCTAssertFalse(script.contains("__CCNOTIFY_PORT_FILE__"), "port placeholder remained in script")

        let perms = try FileManager.default.attributesOfItem(atPath: AppPaths.bridgeScript.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(perms?.int16Value, 0o700, "bridge.sh should be 0700")
    }

    func testInstallPreservesUnrelatedKeysAndHooks() throws {
        try writeSettings([
            "model": "opus",
            "hooks": [
                "Notification": [
                    ["hooks": [["type": "command", "command": "/usr/local/bin/outro-hook"]]]
                ],
                "PreToolUse": [
                    ["matcher": "*", "hooks": [["type": "command", "command": "/algum/guard"]]]
                ]
            ]
        ])

        try HookInstaller.install(token: "tkn")

        let settings = try XCTUnwrap(readSettings())
        XCTAssertEqual(settings["model"] as? String, "opus", "non-hooks key was lost")

        // hook from another author preserved + bridge added
        XCTAssertEqual(bridgeEntryCount(for: "Notification"), 1)
        let notifCommands = hookGroups(for: "Notification")
            .flatMap { ($0["hooks"] as? [[String: Any]]) ?? [] }
            .compactMap { $0["command"] as? String }
        XCTAssertTrue(notifCommands.contains("/usr/local/bin/outro-hook"), "user's hook was removed")

        // unmanaged event untouched
        XCTAssertEqual(bridgeEntryCount(for: "PreToolUse"), 0)
        XCTAssertEqual(hookGroups(for: "PreToolUse").count, 1)
    }

    func testInstallIsIdempotent() throws {
        try HookInstaller.install(token: "tkn")
        try HookInstaller.install(token: "tkn")
        try HookInstaller.install(token: "tkn")

        for event in HookInstaller.managedEvents {
            XCTAssertEqual(bridgeEntryCount(for: event), 1,
                           "reinstalling duplicated bridge entry in \(event)")
        }
    }

    func testInstallBacksUpExistingSettings() throws {
        try writeSettings(["model": "sonnet"])

        try HookInstaller.install(token: "tkn")

        let dir = AppPaths.claudeSettings.deletingLastPathComponent()
        let backups = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasPrefix("settings.json.bak.") }
        XCTAssertEqual(backups.count, 1, "should have created exactly 1 backup")
    }

    func testInstallDoesNotBackUpWhenNoSettingsExist() throws {
        try HookInstaller.install(token: "tkn")

        let dir = AppPaths.claudeSettings.deletingLastPathComponent()
        let backups = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasPrefix("settings.json.bak.") }
        XCTAssertTrue(backups.isEmpty, "should not backup without existing settings.json")
    }

    // MARK: - isInstalled

    func testIsInstalledFalseOnCleanState() {
        XCTAssertFalse(HookInstaller.isInstalled)
    }

    func testIsInstalledFalseWhenOnlyForeignHooks() throws {
        try writeSettings([
            "hooks": ["Notification": [["hooks": [["type": "command", "command": "/x/y"]]]]]
        ])
        XCTAssertFalse(HookInstaller.isInstalled)
    }

    // MARK: - uninstall

    func testUninstallRemovesBridgeButKeepsForeignHooks() throws {
        try writeSettings([
            "hooks": [
                "Notification": [
                    ["hooks": [["type": "command", "command": "/usr/local/bin/outro-hook"]]]
                ]
            ]
        ])
        try HookInstaller.install(token: "tkn")
        XCTAssertTrue(HookInstaller.isInstalled)

        try HookInstaller.uninstall()

        XCTAssertFalse(HookInstaller.isInstalled)
        XCTAssertEqual(bridgeEntryCount(for: "Notification"), 0)
        let notifCommands = hookGroups(for: "Notification")
            .flatMap { ($0["hooks"] as? [[String: Any]]) ?? [] }
            .compactMap { $0["command"] as? String }
        XCTAssertTrue(notifCommands.contains("/usr/local/bin/outro-hook"),
                      "uninstall removed hook that wasn't ours")
    }

    func testUninstallDropsEmptyEventKeysAndHooks() throws {
        try HookInstaller.install(token: "tkn")  // only our hooks

        try HookInstaller.uninstall()

        let settings = try XCTUnwrap(readSettings())
        XCTAssertNil(settings["hooks"], "empty hooks should be removed entirely")
    }

    func testUninstallOnCleanStateIsNoop() throws {
        XCTAssertNoThrow(try HookInstaller.uninstall())
        XCTAssertNil(readSettings())
    }

    // MARK: - writeBridgeOnly

    func testWriteBridgeOnlyReturnsPathAndDoesNotTouchSettings() throws {
        let path = try HookInstaller.writeBridgeOnly(token: "tkn")

        XCTAssertEqual(path, AppPaths.bridgeScript.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: AppPaths.bridgeScript.path))
        XCTAssertNil(readSettings(), "writeBridgeOnly should not write settings.json")
        XCTAssertFalse(HookInstaller.isInstalled)
    }
}
