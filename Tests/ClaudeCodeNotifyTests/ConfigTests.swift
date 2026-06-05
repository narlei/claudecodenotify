import XCTest
@testable import ClaudeCodeNotify

final class ConfigTests: SandboxedTestCase {

    func testLoadOrCreateGeneratesAndPersists() {
        let created = Config.loadOrCreate()
        XCTAssertFalse(created.token.isEmpty)
        XCTAssertFalse(created.onboardingShown)
        XCTAssertFalse(created.donationHidden)
        XCTAssertTrue(FileManager.default.fileExists(atPath: AppPaths.configFile.path),
                      "config.json should have been written")

        // second load reuses the same token (doesn't regenerate)
        let reloaded = Config.loadOrCreate()
        XCTAssertEqual(reloaded.token, created.token)
    }

    func testTokenIsBase64URLSafe() {
        let token = Config.loadOrCreate().token
        XCTAssertFalse(token.contains("+"), "token should be base64url (no +)")
        XCTAssertFalse(token.contains("/"), "token should be base64url (no /)")
        XCTAssertFalse(token.contains("="), "token should be base64url (no padding)")
    }

    func testConfigFileHas0600Permissions() throws {
        _ = Config.loadOrCreate()
        let attrs = try FileManager.default.attributesOfItem(atPath: AppPaths.configFile.path)
        let perms = attrs[.posixPermissions] as? NSNumber
        XCTAssertEqual(perms?.int16Value, 0o600, "config.json (has the token) should be 0600")
    }

    func testMarkOnboardingShownPersists() {
        var cfg = Config.loadOrCreate()
        cfg.markOnboardingShown()
        XCTAssertTrue(Config.loadOrCreate().onboardingShown)
    }

    func testHideDonationPersists() {
        var cfg = Config.loadOrCreate()
        cfg.hideDonation()
        XCTAssertTrue(Config.loadOrCreate().donationHidden)
    }

    func testResilientDecodeKeepsTokenWhenNewFieldsMissing() throws {
        // old config.json with just token — should not break or regenerate.
        _ = try? AppPaths.ensureSupportDirectory()
        try #"{"token":"legacy-token"}"#.write(to: AppPaths.configFile, atomically: true, encoding: .utf8)

        let cfg = Config.loadOrCreate()
        XCTAssertEqual(cfg.token, "legacy-token")
        XCTAssertFalse(cfg.onboardingShown)
        XCTAssertFalse(cfg.donationHidden)
    }
}
