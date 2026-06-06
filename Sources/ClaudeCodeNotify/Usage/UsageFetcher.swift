import Foundation

struct UsageData {
    let util5h: Double   // 0–1
    let reset5h: Date?
    let util7d: Double   // 0–1
    let reset7d: Date?
}

enum UsageFetcher {
    private static let claudeKeychainService = "Claude Code-credentials"
    // Our own entry: the creating app owns it, so macOS won't re-prompt after updates.
    private static let cacheKeychainService = "ClaudeCodeNotify-usage-token"
    private static let cacheKeychainAccount = "accessToken"

    private static let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let claudeCandidates = ["/opt/homebrew/bin/claude", "/usr/local/bin/claude", "claude"]
    private static let refreshCooldown: TimeInterval = 5 * 60
    private static var lastRefreshAttempt: Date = .distantPast

    // MARK: - User-controlled flags

    static var usageBarsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "usageBarsEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "usageBarsEnabled") }
    }

    static var keychainDenied: Bool {
        get { UserDefaults.standard.bool(forKey: "keychainDenied") }
        set { UserDefaults.standard.set(newValue, forKey: "keychainDenied") }
    }

    static func resetKeychainPermission() {
        keychainDenied = false
    }

    static func fetch() async -> UsageData? {
        guard usageBarsEnabled, !keychainDenied else { return nil }
        return await fetchAttempt(retried: false)
    }

    private static func fetchAttempt(retried: Bool) async -> UsageData? {
        guard let token = readToken() else { return nil }

        var req = URLRequest(url: apiURL)
        req.httpMethod = "POST"
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("claude-code/2.1.5", forHTTPHeaderField: "User-Agent")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1,
            "messages": [["role": "user", "content": "hi"]]
        ])
        req.timeoutInterval = 10

        guard let (_, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse else { return nil }

        if (http.statusCode == 401 || http.statusCode == 403), !retried {
            // Stale token — clear our cache so next read falls back to Claude's keychain.
            clearCachedToken()
            let refreshed = await attemptCliRefresh()
            if refreshed { return await fetchAttempt(retried: true) }
            return nil
        }

        let h = { (name: String) -> String? in http.value(forHTTPHeaderField: name) }

        guard let u5 = pct(h("anthropic-ratelimit-unified-5h-utilization")),
              let u7 = pct(h("anthropic-ratelimit-unified-7d-utilization")) else { return nil }

        return UsageData(
            util5h: u5,
            reset5h: epoch(h("anthropic-ratelimit-unified-5h-reset")),
            util7d: u7,
            reset7d: epoch(h("anthropic-ratelimit-unified-7d-reset"))
        )
    }

    private static func attemptCliRefresh() async -> Bool {
        guard Date().timeIntervalSince(lastRefreshAttempt) > refreshCooldown else { return false }
        lastRefreshAttempt = Date()
        return await withCheckedContinuation { continuation in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: claudeCandidates[0])
            p.arguments = ["-p", "hi", "--max-budget-usd", "0.01"]
            p.standardInput = FileHandle.nullDevice
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            p.terminationHandler = { _ in continuation.resume(returning: true) }
            do {
                try p.run()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }

    // MARK: - Token reading

    /// Tries our own cached entry first (no re-prompt after app updates), then falls back
    /// to Claude Code's keychain entry (one-time user permission required).
    private static func readToken() -> String? {
        if let cached = readCachedToken() { return cached }
        return readClaudeToken()
    }

    private static func readCachedToken() -> String? {
        var item: AnyObject?
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: cacheKeychainService,
            kSecAttrAccount: cacheKeychainAccount,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func readClaudeToken() -> String? {
        let username = NSUserName()
        var item: AnyObject?
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: claudeKeychainService,
            kSecAttrAccount: username,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let raw = String(data: data, encoding: .utf8),
                  let token = extractAccessToken(raw) else { return nil }
            cacheToken(token)
            return token
        case errSecItemNotFound:
            // No keychain entry — user likely using a custom API or not logged in via CLI.
            return nil
        case errSecUserCanceled, errSecInteractionNotAllowed:
            keychainDenied = true
            return nil
        default:
            return nil
        }
    }

    // MARK: - Token cache management

    private static func cacheToken(_ token: String) {
        let data = Data(token.utf8)
        let lookupQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: cacheKeychainService,
            kSecAttrAccount: cacheKeychainAccount
        ]
        let updateAttrs: [CFString: Any] = [kSecValueData: data]
        if SecItemUpdate(lookupQuery as CFDictionary, updateAttrs as CFDictionary) == errSecItemNotFound {
            var addQuery = lookupQuery
            addQuery[kSecValueData] = data
            // kSecAttrAccessibleAfterFirstUnlock: readable after first device unlock, no user prompt.
            addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    private static func clearCachedToken() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: cacheKeychainService,
            kSecAttrAccount: cacheKeychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Helpers

    private static func extractAccessToken(_ raw: String) -> String? {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String,
              !token.isEmpty else { return nil }
        return token
    }

    private static func pct(_ s: String?) -> Double? {
        guard let s, let v = Double(s) else { return nil }
        return max(0, min(1, v))
    }

    private static func epoch(_ s: String?) -> Date? {
        guard let s, let v = Double(s) else { return nil }
        return Date(timeIntervalSince1970: v)
    }
}
