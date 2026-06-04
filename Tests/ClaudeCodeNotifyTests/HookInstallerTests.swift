import XCTest
@testable import ClaudeCodeNotify

final class HookInstallerTests: SandboxedTestCase {

    // MARK: - install

    func testInstallRegistersBridgeForAllManagedEvents() throws {
        try HookInstaller.install(token: "tkn")

        for event in HookInstaller.managedEvents {
            XCTAssertEqual(bridgeEntryCount(for: event), 1,
                           "esperava exatamente 1 entrada do bridge em \(event)")
        }
        XCTAssertTrue(HookInstaller.isInstalled)
    }

    func testInstallWritesBridgeScriptWith0700AndSubstitutions() throws {
        try HookInstaller.install(token: "secret-token-123")

        let script = try String(contentsOf: AppPaths.bridgeScript, encoding: .utf8)
        XCTAssertTrue(script.contains("TOKEN=\"secret-token-123\""), "token não substituído")
        XCTAssertTrue(script.contains(AppPaths.portFile.path), "port file não substituído")
        XCTAssertFalse(script.contains("__CCNOTIFY_TOKEN__"), "placeholder do token ficou no script")
        XCTAssertFalse(script.contains("__CCNOTIFY_PORT_FILE__"), "placeholder do port ficou no script")

        let perms = try FileManager.default.attributesOfItem(atPath: AppPaths.bridgeScript.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(perms?.int16Value, 0o700, "bridge.sh deveria ser 0700")
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
        XCTAssertEqual(settings["model"] as? String, "opus", "chave não-hooks foi perdida")

        // hook de outro autor preservado + bridge adicionado
        XCTAssertEqual(bridgeEntryCount(for: "Notification"), 1)
        let notifCommands = hookGroups(for: "Notification")
            .flatMap { ($0["hooks"] as? [[String: Any]]) ?? [] }
            .compactMap { $0["command"] as? String }
        XCTAssertTrue(notifCommands.contains("/usr/local/bin/outro-hook"), "hook do usuário foi removido")

        // evento não-gerenciado intocado
        XCTAssertEqual(bridgeEntryCount(for: "PreToolUse"), 0)
        XCTAssertEqual(hookGroups(for: "PreToolUse").count, 1)
    }

    func testInstallIsIdempotent() throws {
        try HookInstaller.install(token: "tkn")
        try HookInstaller.install(token: "tkn")
        try HookInstaller.install(token: "tkn")

        for event in HookInstaller.managedEvents {
            XCTAssertEqual(bridgeEntryCount(for: event), 1,
                           "instalar de novo duplicou a entrada do bridge em \(event)")
        }
    }

    func testInstallBacksUpExistingSettings() throws {
        try writeSettings(["model": "sonnet"])

        try HookInstaller.install(token: "tkn")

        let dir = AppPaths.claudeSettings.deletingLastPathComponent()
        let backups = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasPrefix("settings.json.bak.") }
        XCTAssertEqual(backups.count, 1, "deveria ter criado exatamente 1 backup")
    }

    func testInstallDoesNotBackUpWhenNoSettingsExist() throws {
        try HookInstaller.install(token: "tkn")

        let dir = AppPaths.claudeSettings.deletingLastPathComponent()
        let backups = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasPrefix("settings.json.bak.") }
        XCTAssertTrue(backups.isEmpty, "não deveria fazer backup sem settings.json prévio")
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
                      "uninstall removeu hook que não era nosso")
    }

    func testUninstallDropsEmptyEventKeysAndHooks() throws {
        try HookInstaller.install(token: "tkn")  // só nossos hooks

        try HookInstaller.uninstall()

        let settings = try XCTUnwrap(readSettings())
        XCTAssertNil(settings["hooks"], "hooks vazio deveria ser removido por completo")
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
        XCTAssertNil(readSettings(), "writeBridgeOnly não deveria escrever settings.json")
        XCTAssertFalse(HookInstaller.isInstalled)
    }
}
