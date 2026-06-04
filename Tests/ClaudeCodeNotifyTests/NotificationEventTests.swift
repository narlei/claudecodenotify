import XCTest
@testable import ClaudeCodeNotify

final class NotificationPayloadTests: XCTestCase {

    func testDecodeMapsSnakeCaseKeys() throws {
        let json = """
        {"hook_event_name":"Notification","notification_type":"permission_prompt",
         "message":"pode rodar?","cwd":"/Users/x/proj","session_id":"abc",
         "last_assistant_message":"feito"}
        """
        let payload = try XCTUnwrap(NotificationPayload.decode(from: Data(json.utf8)))
        XCTAssertEqual(payload.hookEventName, "Notification")
        XCTAssertEqual(payload.notificationType, "permission_prompt")
        XCTAssertEqual(payload.message, "pode rodar?")
        XCTAssertEqual(payload.cwd, "/Users/x/proj")
        XCTAssertEqual(payload.sessionID, "abc")
        XCTAssertEqual(payload.lastAssistantMessage, "feito")
    }

    func testDecodeToleratesMissingFields() throws {
        let payload = try XCTUnwrap(NotificationPayload.decode(from: Data(#"{"hook_event_name":"Stop"}"#.utf8)))
        XCTAssertEqual(payload.hookEventName, "Stop")
        XCTAssertNil(payload.message)
        XCTAssertNil(payload.cwd)
    }

    func testDecodeReturnsNilOnGarbage() {
        XCTAssertNil(NotificationPayload.decode(from: Data("not json".utf8)))
    }
}

final class NotificationEventTests: XCTestCase {

    private func event(hook: String?, type: String? = nil,
                       cwd: String? = nil) -> NotificationEvent? {
        var fields: [String] = []
        if let hook { fields.append("\"hook_event_name\":\"\(hook)\"") }
        if let type { fields.append("\"notification_type\":\"\(type)\"") }
        if let cwd { fields.append("\"cwd\":\"\(cwd)\"") }
        let json = "{\(fields.joined(separator: ","))}"
        let payload = NotificationPayload.decode(from: Data(json.utf8))!
        return NotificationEvent(payload: payload, termProgram: "ghostty", hostPIDs: [42])
    }

    func testStopMapsToStopKind() {
        XCTAssertEqual(event(hook: "Stop")?.kind, .stop)
    }

    func testPermissionPromptMapsToPermission() {
        XCTAssertEqual(event(hook: "Notification", type: "permission_prompt")?.kind, .permission)
    }

    func testIdlePromptMapsToIdle() {
        XCTAssertEqual(event(hook: "Notification", type: "idle_prompt")?.kind, .idle)
    }

    func testUnknownNotificationTypeMapsToOther() {
        let e = event(hook: "Notification", type: "something_else")
        XCTAssertEqual(e?.kind, .other)
        XCTAssertFalse(e?.shouldNotify ?? true)
    }

    func testUnknownHookMapsToOther() {
        XCTAssertEqual(event(hook: "PreToolUse")?.kind, .other)
    }

    func testShouldNotifyTrueForRealEvents() {
        XCTAssertTrue(event(hook: "Stop")?.shouldNotify ?? false)
        XCTAssertTrue(event(hook: "Notification", type: "idle_prompt")?.shouldNotify ?? false)
    }

    func testProjectNameIsLastPathComponent() {
        XCTAssertEqual(event(hook: "Stop", cwd: "/Users/x/my-project")?.projectName, "my-project")
    }

    func testProjectNameEmptyWhenNoCwd() {
        XCTAssertEqual(event(hook: "Stop")?.projectName, "")
    }

    func testCarriesTermProgramAndPIDs() {
        let e = event(hook: "Stop")
        XCTAssertEqual(e?.termProgram, "ghostty")
        XCTAssertEqual(e?.hostPIDs, [42])
    }
}
