import XCTest
@testable import ClaudeCodeNotify

final class ConfigTests: SandboxedTestCase {

    func testLoadOrCreateGeneratesAndPersists() {
        let created = Config.loadOrCreate()
        XCTAssertFalse(created.token.isEmpty)
        XCTAssertFalse(created.onboardingShown)
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

    func testResilientDecodeKeepsTokenWhenNewFieldsMissing() throws {
        // old config.json with just token — should not break or regenerate.
        _ = try? AppPaths.ensureSupportDirectory()
        try #"{"token":"legacy-token"}"#.write(to: AppPaths.configFile, atomically: true, encoding: .utf8)

        let cfg = Config.loadOrCreate()
        XCTAssertEqual(cfg.token, "legacy-token")
        XCTAssertFalse(cfg.onboardingShown)
    }

    // MARK: - Star prompt

    func testNotEligibleBeforeThresholdAndEligibleAtThreshold() {
        var cfg = Config(token: "t")
        XCTAssertFalse(cfg.isStarPromptEligible, "should not be eligible with 0 notifications")

        // Drive deliveries up to one short of the threshold.
        for _ in 0..<(Config.starPromptThreshold - 1) {
            cfg.recordNotificationDelivered()
        }
        XCTAssertFalse(cfg.isStarPromptEligible, "should not be eligible just below threshold")

        cfg.recordNotificationDelivered() // now exactly at threshold
        XCTAssertEqual(cfg.notificationsDelivered, Config.starPromptThreshold)
        XCTAssertTrue(cfg.isStarPromptEligible, "should be eligible exactly at threshold")
    }

    func testDeferredSchedulesNextEligibleAndBlocksUntilThen() throws {
        var cfg = Config(token: "t", notificationsDelivered: Config.starPromptThreshold)
        XCTAssertTrue(cfg.isStarPromptEligible)

        cfg.starPromptDeferred()
        XCTAssertEqual(cfg.starPromptDeferCount, 1)
        XCTAssertFalse(cfg.starPromptDone)
        XCTAssertFalse(cfg.isStarPromptEligible, "should not be eligible right after deferring")

        // Next eligible date should be ~7 days out.
        let next = try XCTUnwrap(cfg.starPromptNextEligibleDate)
        let expected = Date().addingTimeInterval(Config.starPromptDeferInterval)
        XCTAssertEqual(next.timeIntervalSinceReferenceDate,
                       expected.timeIntervalSinceReferenceDate,
                       accuracy: 5,
                       "next eligible date should be ~7 days out")
    }

    func testMaxDefersMarksDoneAndNeverEligible() {
        var cfg = Config(token: "t", notificationsDelivered: Config.starPromptThreshold)
        for _ in 0..<Config.starPromptMaxDefers {
            cfg.starPromptDeferred()
        }
        XCTAssertEqual(cfg.starPromptDeferCount, Config.starPromptMaxDefers)
        XCTAssertTrue(cfg.starPromptDone, "should be done after max defers")
        XCTAssertFalse(cfg.isStarPromptEligible, "should never be eligible after max defers")

        // Even with the cooldown cleared, done keeps it from reappearing.
        cfg.starPromptNextEligibleDate = nil
        XCTAssertFalse(cfg.isStarPromptEligible)
    }

    func testCompletedMarksDoneAndNotEligible() {
        var cfg = Config(token: "t", notificationsDelivered: Config.starPromptThreshold)
        XCTAssertTrue(cfg.isStarPromptEligible)

        cfg.starPromptCompleted()
        XCTAssertTrue(cfg.starPromptDone)
        XCTAssertFalse(cfg.isStarPromptEligible, "should not be eligible once completed")

        XCTAssertTrue(Config.loadOrCreate().starPromptDone, "completion should persist")
    }

    func testResilientDecodeStarFieldsDefaultWhenMissing() throws {
        // Old config.json with only token + onboardingShown — new star fields default.
        _ = try? AppPaths.ensureSupportDirectory()
        try #"{"token":"legacy","onboardingShown":true}"#
            .write(to: AppPaths.configFile, atomically: true, encoding: .utf8)

        let cfg = Config.loadOrCreate()
        XCTAssertEqual(cfg.token, "legacy")
        XCTAssertTrue(cfg.onboardingShown)
        XCTAssertEqual(cfg.notificationsDelivered, 0)
        XCTAssertEqual(cfg.starPromptDeferCount, 0)
        XCTAssertNil(cfg.starPromptNextEligibleDate)
        XCTAssertFalse(cfg.starPromptDone)
    }
}
