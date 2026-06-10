import Foundation

/// Surgical access to ~/.claude.json (Claude Code CLI state). Only the `oauthAccount`
/// key is ever touched — the file is large and holds unrelated CLI state that must
/// survive a profile switch byte-for-byte semantically (re-serialized, same content).
enum ClaudeConfigFile {
    struct AccountIdentity: Equatable {
        var email: String
        var orgUuid: String?
        var orgName: String?
    }

    /// Current account identity, or nil if the file/key is missing (not logged in).
    static func readIdentity() -> AccountIdentity? {
        guard let account = readOAuthAccount(),
              let email = account["emailAddress"] as? String, !email.isEmpty else { return nil }
        return AccountIdentity(email: email,
                               orgUuid: account["organizationUuid"] as? String,
                               orgName: account["organizationName"] as? String)
    }

    /// Full `oauthAccount` object as compact JSON, for storing in a Profile.
    static func readOAuthAccountJSON() -> Data? {
        guard let account = readOAuthAccount() else { return nil }
        return try? JSONSerialization.data(withJSONObject: account, options: [.sortedKeys])
    }

    /// Replaces only the `oauthAccount` key, preserving every other key in the file.
    static func writeOAuthAccountJSON(_ json: Data) throws {
        guard let account = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any] else {
            throw ClaudeConfigError.invalidAccountJSON
        }
        var root = readRoot() ?? [:]
        root["oauthAccount"] = account
        let data = try JSONSerialization.data(withJSONObject: root,
                                              options: [.sortedKeys, .withoutEscapingSlashes])
        try data.write(to: AppPaths.claudeConfig, options: .atomic)
    }

    enum ClaudeConfigError: Error {
        case invalidAccountJSON
    }

    // MARK: - Internals

    private static func readRoot() -> [String: Any]? {
        guard let data = try? Data(contentsOf: AppPaths.claudeConfig) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func readOAuthAccount() -> [String: Any]? {
        readRoot()?["oauthAccount"] as? [String: Any]
    }
}
