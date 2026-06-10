import XCTest
@testable import ClaudeCodeNotify

final class ClaudeConfigFileTests: SandboxedTestCase {

    private func writeClaudeConfig(_ dict: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: dict)
        try data.write(to: AppPaths.claudeConfig)
    }

    func testReadIdentity() throws {
        try writeClaudeConfig([
            "oauthAccount": [
                "emailAddress": "me@example.com",
                "organizationUuid": "org-123",
                "organizationName": "Acme",
                "billingType": "stripe_subscription"
            ],
            "numStartups": 42
        ])

        let identity = try XCTUnwrap(ClaudeConfigFile.readIdentity())
        XCTAssertEqual(identity.email, "me@example.com")
        XCTAssertEqual(identity.orgUuid, "org-123")
        XCTAssertEqual(identity.orgName, "Acme")
    }

    func testReadIdentityMissingFileOrKey() throws {
        XCTAssertNil(ClaudeConfigFile.readIdentity())
        try writeClaudeConfig(["numStartups": 1])
        XCTAssertNil(ClaudeConfigFile.readIdentity())
    }

    func testWritePreservesUnrelatedKeys() throws {
        try writeClaudeConfig([
            "oauthAccount": ["emailAddress": "old@example.com"],
            "numStartups": 42,
            "projects": ["/tmp/foo": ["allowedTools": ["Bash"]]],
            "tipsHistory": ["memory": 3]
        ])

        let newAccount = try JSONSerialization.data(
            withJSONObject: ["emailAddress": "new@example.com", "organizationUuid": "org-9"])
        try ClaudeConfigFile.writeOAuthAccountJSON(newAccount)

        let root = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(contentsOf: AppPaths.claudeConfig)) as? [String: Any])
        XCTAssertEqual(root["numStartups"] as? Int, 42)
        XCTAssertNotNil(root["projects"])
        XCTAssertNotNil(root["tipsHistory"])
        let account = try XCTUnwrap(root["oauthAccount"] as? [String: Any])
        XCTAssertEqual(account["emailAddress"] as? String, "new@example.com")
        XCTAssertEqual(account["organizationUuid"] as? String, "org-9")
    }

    func testReadOAuthAccountJSONRoundTripsThroughProfile() throws {
        try writeClaudeConfig([
            "oauthAccount": ["emailAddress": "me@example.com", "displayName": "Me"]
        ])
        let json = try XCTUnwrap(ClaudeConfigFile.readOAuthAccountJSON())

        // Wipe and restore — identity must survive the round trip.
        try writeClaudeConfig(["oauthAccount": ["emailAddress": "other@example.com"]])
        try ClaudeConfigFile.writeOAuthAccountJSON(json)
        XCTAssertEqual(ClaudeConfigFile.readIdentity()?.email, "me@example.com")
    }

    func testWriteInvalidJSONThrows() {
        XCTAssertThrowsError(try ClaudeConfigFile.writeOAuthAccountJSON(Data("not json".utf8)))
    }
}
