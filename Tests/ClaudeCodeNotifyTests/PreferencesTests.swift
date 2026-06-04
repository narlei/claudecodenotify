import XCTest
@testable import ClaudeCodeNotify

final class PreferencesTests: SandboxedTestCase {

    func testLoadReturnsDefaultWhenMissing() {
        let prefs = Preferences.load()
        XCTAssertEqual(prefs.permission.durationSeconds, Preferences.default.permission.durationSeconds)
        XCTAssertEqual(prefs.stop.soundName, Preferences.default.stop.soundName)
    }

    func testSaveLoadRoundTrip() {
        var prefs = Preferences.default
        prefs.idle = Preferences.TypePref(durationSeconds: 42, soundName: nil)
        prefs.stop = Preferences.TypePref(durationSeconds: 5, soundName: "Submarine")
        prefs.save()

        let loaded = Preferences.load()
        XCTAssertEqual(loaded.idle.durationSeconds, 42)
        XCTAssertNil(loaded.idle.soundName)
        XCTAssertEqual(loaded.stop.soundName, "Submarine")
    }

    func testLoadFallsBackToDefaultOnCorruptFile() throws {
        _ = try? AppPaths.ensureSupportDirectory()
        try "not json".write(to: AppPaths.preferencesFile, atomically: true, encoding: .utf8)

        let prefs = Preferences.load()
        XCTAssertEqual(prefs.permission.durationSeconds, Preferences.default.permission.durationSeconds)
    }

    func testPrefForKindMapping() {
        let prefs = Preferences.default
        XCTAssertEqual(prefs.pref(for: .permission).soundName, "Glass")
        XCTAssertEqual(prefs.pref(for: .idle).soundName, "Tink")
        XCTAssertEqual(prefs.pref(for: .stop).soundName, "Hero")
        // .other cai em permission (fallback)
        XCTAssertEqual(prefs.pref(for: .other).soundName, prefs.permission.soundName)
    }
}
