import XCTest
@testable import ClaudeCodeNotify

/// In-memory keychain double — tests never touch the real keychain.
final class FakeCredentialStore: CredentialStoring {
    var claude: KeychainReadResult = .notFound
    var snapshots: [UUID: String] = [:]
    var claudeWriteError: Error?

    func readClaudeCredentials() -> KeychainReadResult { claude }

    func writeClaudeCredentials(_ blob: String) throws {
        if let claudeWriteError { throw claudeWriteError }
        claude = .success(blob)
    }

    func readSnapshot(profileID: UUID) -> KeychainReadResult {
        snapshots[profileID].map { .success($0) } ?? .notFound
    }

    func writeSnapshot(profileID: UUID, blob: String) throws {
        snapshots[profileID] = blob
    }

    func deleteSnapshot(profileID: UUID) {
        snapshots.removeValue(forKey: profileID)
    }
}

final class ProfileManagerTests: SandboxedTestCase {
    private var keychain: FakeCredentialStore!
    private var usageToReturn: UsageData?

    override func setUpWithError() throws {
        try super.setUpWithError()
        keychain = FakeCredentialStore()
        usageToReturn = nil
    }

    private func makeManager() -> ProfileManager {
        let usage = { self.usageToReturn }
        return ProfileManager(credentials: keychain, fetchUsage: { usage() })
    }

    /// Simulates `claude /login`: writes oauthAccount to ~/.claude.json + blob to keychain.
    private func login(email: String, orgUuid: String, blob: String) throws {
        let root: [String: Any] = [
            "oauthAccount": ["emailAddress": email, "organizationUuid": orgUuid,
                             "organizationName": "\(email)'s Org"],
            "numStartups": 7
        ]
        try JSONSerialization.data(withJSONObject: root).write(to: AppPaths.claudeConfig)
        keychain.claude = .success(blob)
    }

    // MARK: - Capture

    func testCaptureCreatesProfileAndSnapshot() throws {
        try login(email: "me@home.com", orgUuid: "org-home", blob: "blob-home-1")
        let manager = makeManager()

        let profile = try manager.captureCurrentAccount(name: "Pessoal", emoji: "🏠")

        XCTAssertEqual(profile.accountEmail, "me@home.com")
        XCTAssertEqual(profile.accountOrgUuid, "org-home")
        XCTAssertEqual(keychain.snapshots[profile.id], "blob-home-1")
        XCTAssertEqual(manager.activeProfile?.id, profile.id)
        XCTAssertFalse(profile.oauthAccountJSON.isEmpty)
        // persisted
        XCTAssertEqual(ProfileStore.load().profiles.count, 1)
    }

    func testCaptureSameAccountUpdatesInsteadOfDuplicating() throws {
        try login(email: "me@home.com", orgUuid: "org-home", blob: "blob-v1")
        let manager = makeManager()
        let first = try manager.captureCurrentAccount(name: "Pessoal", emoji: "🏠")

        keychain.claude = .success("blob-v2")
        let second = try manager.captureCurrentAccount(name: "ignored", emoji: "💼")

        XCTAssertEqual(second.id, first.id)
        XCTAssertEqual(manager.profiles.count, 1)
        XCTAssertEqual(manager.profiles.first?.name, "Pessoal") // keeps original name/emoji
        XCTAssertEqual(keychain.snapshots[first.id], "blob-v2") // snapshot refreshed
    }

    func testCaptureFailsWhenNotLoggedIn() {
        let manager = makeManager()
        XCTAssertThrowsError(try manager.captureCurrentAccount(name: "x", emoji: "x")) {
            XCTAssertEqual($0 as? ProfileManager.CaptureError, .notLoggedIn)
        }
    }

    func testCaptureFailsWhenKeychainUnavailable() throws {
        try login(email: "me@home.com", orgUuid: "org-home", blob: "b")
        keychain.claude = .denied
        let manager = makeManager()
        XCTAssertThrowsError(try manager.captureCurrentAccount(name: "x", emoji: "x")) {
            XCTAssertEqual($0 as? ProfileManager.CaptureError, .credentialsUnavailable)
        }
    }

    // MARK: - Switch

    /// Full happy path: capture two accounts, switch back to the first.
    func testSwitchRestoresKeychainAndConfigAndResnapshotsExiting() async throws {
        try login(email: "me@home.com", orgUuid: "org-home", blob: "blob-home")
        let manager = makeManager()
        let personal = try manager.captureCurrentAccount(name: "Pessoal", emoji: "🏠")

        try login(email: "me@corp.com", orgUuid: "org-corp", blob: "blob-corp-v1")
        let work = try manager.captureCurrentAccount(name: "Empresa", emoji: "💼")
        XCTAssertEqual(manager.activeProfile?.id, work.id)

        // CLI rotates work tokens while work is active.
        keychain.claude = .success("blob-corp-v2")

        let result = try await manager.switchTo(profileID: personal.id)

        XCTAssertEqual(result.profile.id, personal.id)
        XCTAssertEqual(manager.activeProfile?.id, personal.id)
        // Keychain now holds personal credentials.
        XCTAssertEqual(keychain.claude, .success("blob-home"))
        // Exiting profile re-snapshotted with the rotated blob.
        XCTAssertEqual(keychain.snapshots[work.id], "blob-corp-v2")
        // ~/.claude.json identity restored, unrelated keys preserved.
        XCTAssertEqual(ClaudeConfigFile.readIdentity()?.email, "me@home.com")
        let root = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(contentsOf: AppPaths.claudeConfig)) as? [String: Any])
        XCTAssertEqual(root["numStartups"] as? Int, 7)
    }

    func testSwitchCachesUsageOnTarget() async throws {
        try login(email: "a@x.com", orgUuid: "o1", blob: "blob-a")
        let manager = makeManager()
        let a = try manager.captureCurrentAccount(name: "A", emoji: "🅰️")
        try login(email: "b@x.com", orgUuid: "o2", blob: "blob-b")
        _ = try manager.captureCurrentAccount(name: "B", emoji: "🅱️")

        usageToReturn = UsageData(util5h: 0.42, reset5h: nil, util7d: 0.07, reset7d: nil)
        let result = try await manager.switchTo(profileID: a.id)

        XCTAssertEqual(result.usage?.util5h, 0.42)
        let cached = manager.profiles.first { $0.id == a.id }?.cachedUsage
        XCTAssertEqual(cached?.util5h, 0.42)
        XCTAssertEqual(cached?.util7d, 0.07)
    }

    func testSwitchToActiveProfileOnlyRefreshesUsage() async throws {
        try login(email: "a@x.com", orgUuid: "o1", blob: "blob-a")
        let manager = makeManager()
        let a = try manager.captureCurrentAccount(name: "A", emoji: "🅰️")

        keychain.claude = .success("blob-a-rotated")
        usageToReturn = UsageData(util5h: 0.5, reset5h: nil, util7d: 0.1, reset7d: nil)
        let result = try await manager.switchTo(profileID: a.id)

        XCTAssertEqual(result.usage?.util5h, 0.5)
        // No restore happened: keychain untouched.
        XCTAssertEqual(keychain.claude, .success("blob-a-rotated"))
    }

    func testSwitchWithMissingSnapshotThrowsAndKeepsState() async throws {
        try login(email: "a@x.com", orgUuid: "o1", blob: "blob-a")
        let manager = makeManager()
        let a = try manager.captureCurrentAccount(name: "A", emoji: "🅰️")
        try login(email: "b@x.com", orgUuid: "o2", blob: "blob-b")
        let b = try manager.captureCurrentAccount(name: "B", emoji: "🅱️")

        keychain.snapshots.removeValue(forKey: a.id)

        do {
            _ = try await manager.switchTo(profileID: a.id)
            XCTFail("expected missingSnapshot")
        } catch let error as ProfileManager.SwitchError {
            XCTAssertEqual(error, .missingSnapshot)
        }
        // Nothing changed: B still active, keychain still B's.
        XCTAssertEqual(manager.activeProfile?.id, b.id)
        XCTAssertEqual(keychain.claude, .success("blob-b"))
    }

    func testSwitchUsageFetchFailureDoesNotFailSwitch() async throws {
        try login(email: "a@x.com", orgUuid: "o1", blob: "blob-a")
        let manager = makeManager()
        let a = try manager.captureCurrentAccount(name: "A", emoji: "🅰️")
        try login(email: "b@x.com", orgUuid: "o2", blob: "blob-b")
        _ = try manager.captureCurrentAccount(name: "B", emoji: "🅱️")

        usageToReturn = nil
        let result = try await manager.switchTo(profileID: a.id)

        XCTAssertNil(result.usage)
        XCTAssertEqual(manager.activeProfile?.id, a.id)
    }

    // MARK: - Reconcile

    func testReconcileAdoptsKnownProfileAfterManualLogin() throws {
        try login(email: "a@x.com", orgUuid: "o1", blob: "blob-a")
        let manager = makeManager()
        let a = try manager.captureCurrentAccount(name: "A", emoji: "🅰️")
        try login(email: "b@x.com", orgUuid: "o2", blob: "blob-b")
        let b = try manager.captureCurrentAccount(name: "B", emoji: "🅱️")
        XCTAssertEqual(manager.activeProfile?.id, b.id)

        // User runs `claude /login` back into A by hand (fresh tokens).
        try login(email: "a@x.com", orgUuid: "o1", blob: "blob-a-fresh")
        manager.reconcile()

        XCTAssertEqual(manager.activeProfile?.id, a.id)
        XCTAssertEqual(keychain.snapshots[a.id], "blob-a-fresh") // snapshot refreshed
    }

    func testReconcileUnknownAccountNotifiesAndNeverTouchesKeychain() throws {
        try login(email: "a@x.com", orgUuid: "o1", blob: "blob-a")
        let manager = makeManager()
        let a = try manager.captureCurrentAccount(name: "A", emoji: "🅰️")

        var detected: ClaudeConfigFile.AccountIdentity?
        manager.onUnknownAccountDetected = { detected = $0 }

        try login(email: "stranger@x.com", orgUuid: "o9", blob: "blob-stranger")
        manager.reconcile()

        XCTAssertEqual(detected?.email, "stranger@x.com")
        XCTAssertEqual(manager.activeProfile?.id, a.id)          // active unchanged
        XCTAssertEqual(keychain.claude, .success("blob-stranger")) // keychain untouched
        XCTAssertNil(keychain.snapshots.values.first { $0 == "blob-stranger" })
    }

    func testReconcileNoOpWhenIdentityMatchesActive() throws {
        try login(email: "a@x.com", orgUuid: "o1", blob: "blob-a")
        let manager = makeManager()
        _ = try manager.captureCurrentAccount(name: "A", emoji: "🅰️")

        var changes = 0
        let observer = NotificationCenter.default.addObserver(
            forName: .ccnotifyProfilesDidChange, object: manager, queue: nil) { _ in changes += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }
        manager.reconcile()
        XCTAssertEqual(changes, 0)
    }

    // MARK: - Editing

    func testDeleteProfileRemovesSnapshotButKeepsKeychain() throws {
        try login(email: "a@x.com", orgUuid: "o1", blob: "blob-a")
        let manager = makeManager()
        let a = try manager.captureCurrentAccount(name: "A", emoji: "🅰️")

        manager.deleteProfile(id: a.id)

        XCTAssertTrue(manager.profiles.isEmpty)
        XCTAssertNil(manager.activeProfile)
        XCTAssertNil(keychain.snapshots[a.id])
        XCTAssertEqual(keychain.claude, .success("blob-a")) // never logs anyone out
    }

    func testUpdatePersistsNameEmojiHotkey() throws {
        try login(email: "a@x.com", orgUuid: "o1", blob: "blob-a")
        let manager = makeManager()
        var a = try manager.captureCurrentAccount(name: "A", emoji: "🅰️")

        a.name = "Pessoal"
        a.emoji = "🏠"
        a.hotkey = Profile.Hotkey(keyCode: 35, modifiers: 0x100)
        manager.update(a)

        let reloaded = ProfileStore.load().profiles.first
        XCTAssertEqual(reloaded?.name, "Pessoal")
        XCTAssertEqual(reloaded?.emoji, "🏠")
        XCTAssertEqual(reloaded?.hotkey?.keyCode, 35)
    }

    func testIsMultiAccountThreshold() throws {
        let manager = makeManager()
        XCTAssertFalse(manager.isMultiAccount)
        try login(email: "a@x.com", orgUuid: "o1", blob: "blob-a")
        _ = try manager.captureCurrentAccount(name: "A", emoji: "🅰️")
        XCTAssertFalse(manager.isMultiAccount)
        try login(email: "b@x.com", orgUuid: "o2", blob: "blob-b")
        _ = try manager.captureCurrentAccount(name: "B", emoji: "🅱️")
        XCTAssertTrue(manager.isMultiAccount)
    }
}
