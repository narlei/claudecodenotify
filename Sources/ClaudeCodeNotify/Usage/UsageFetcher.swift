import Foundation

struct UsageData {
    let util5h: Double   // 0–1
    let reset5h: Date?
    let util7d: Double   // 0–1
    let reset7d: Date?
}

enum UsageFetcher {
    private static let keychainService = "Claude Code-credentials"
    private static let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!

    static func fetch() async -> UsageData? {
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

    private static func readToken() -> String? {
        let username = NSUserName()
        var item: AnyObject?
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: username,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let raw = String(data: data, encoding: .utf8) else { return nil }
        return extractAccessToken(raw)
    }

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
