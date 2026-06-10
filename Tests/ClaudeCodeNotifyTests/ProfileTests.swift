import XCTest
@testable import ClaudeCodeNotify

final class ProfileTests: SandboxedTestCase {

    private func makeProfile(name: String = "Pessoal", email: String = "me@example.com",
                             orgUuid: String? = "org-1") -> Profile {
        Profile(name: name, emoji: "🏠",
                accountEmail: email, accountOrgUuid: orgUuid, accountOrgName: "My Org",
                oauthAccountJSON: Data("{\"emailAddress\":\"\(email)\"}".utf8))
    }

    func testRoundTrip() {
        var store = ProfileStore.empty
        var p = makeProfile()
        p.hotkey = Profile.Hotkey(keyCode: 35, modifiers: 0x100)
        p.cachedUsage = Profile.CachedUsage(util5h: 0.42, util7d: 0.1,
                                            reset5h: Date(timeIntervalSince1970: 1_781_095_200),
                                            reset7d: nil, fetchedAt: Date())
        store.profiles = [p]
        store.activeProfileID = p.id
        store.save()

        let loaded = ProfileStore.load()
        XCTAssertEqual(loaded.profiles, [p])
        XCTAssertEqual(loaded.activeProfile?.id, p.id)
    }

    func testLoadMissingFileReturnsEmpty() {
        let loaded = ProfileStore.load()
        XCTAssertTrue(loaded.profiles.isEmpty)
        XCTAssertNil(loaded.activeProfileID)
    }

    func testResilientDecodeWithMissingOptionalFields() throws {
        // Simulates an old/minimal profiles.json: only required fields present.
        let json = """
        {"profiles":[{"id":"6F1C1B2A-0000-4000-8000-000000000001",
                      "name":"Work","accountEmail":"w@corp.com"}]}
        """
        try AppPaths.ensureSupportDirectory()
        try json.data(using: .utf8)!.write(to: AppPaths.profilesFile)

        let loaded = ProfileStore.load()
        XCTAssertEqual(loaded.profiles.count, 1)
        let p = try XCTUnwrap(loaded.profiles.first)
        XCTAssertEqual(p.name, "Work")
        XCTAssertEqual(p.emoji, "👤") // default applied
        XCTAssertNil(p.hotkey)
        XCTAssertNil(p.cachedUsage)
        XCTAssertNil(loaded.activeProfileID)
    }

    func testSaveRestrictsPermissions() throws {
        ProfileStore.empty.save()
        let attrs = try FileManager.default.attributesOfItem(atPath: AppPaths.profilesFile.path)
        XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.int16Value, 0o600)
    }

    func testMatchesIsOrgAware() {
        let personal = makeProfile(email: "me@example.com", orgUuid: "org-personal")
        XCTAssertTrue(personal.matches(email: "me@example.com", orgUuid: "org-personal"))
        // Same email in a different org is a different account.
        XCTAssertFalse(personal.matches(email: "me@example.com", orgUuid: "org-enterprise"))
        XCTAssertFalse(personal.matches(email: nil, orgUuid: "org-personal"))
    }

    func testProfileLookupByIdentity() {
        let a = makeProfile(name: "A", email: "a@x.com", orgUuid: "o1")
        let b = makeProfile(name: "B", email: "b@x.com", orgUuid: "o2")
        let store = ProfileStore(profiles: [a, b], activeProfileID: a.id)
        XCTAssertEqual(store.profile(matchingEmail: "b@x.com", orgUuid: "o2")?.id, b.id)
        XCTAssertNil(store.profile(matchingEmail: "b@x.com", orgUuid: "o1"))
    }
}
