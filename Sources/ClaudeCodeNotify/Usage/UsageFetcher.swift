import Foundation

struct UsageData {
    let util5h: Double   // 0–1
    let reset5h: Date?
    let util7d: Double   // 0–1
    let reset7d: Date?
}

enum UsageFetcher {
    private static let credentialStore: CredentialStoring = SecurityToolCredentialStore()

    private static let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let claudeCandidates = [
        "\(NSHomeDirectory())/.local/bin/claude",
        "/opt/homebrew/bin/claude",
        "/usr/local/bin/claude",
    ]
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

    /// Whether a keychain read has ever succeeded. Persisted so the UI (welcome
    /// screen, preferences) can reflect already-granted access across launches,
    /// instead of asking again every time. Updated by `readToken()` on every read.
    static var keychainGranted: Bool {
        get { UserDefaults.standard.bool(forKey: "keychainGranted") }
        set { UserDefaults.standard.set(newValue, forKey: "keychainGranted") }
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
            // Stale token — let the CLI refresh Claude's keychain entry, then re-read it.
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

    /// First `claude` candidate that exists and is executable on this machine.
    private static func resolveClaude() -> String? {
        claudeCandidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func attemptCliRefresh() async -> Bool {
        guard Date().timeIntervalSince(lastRefreshAttempt) > refreshCooldown else { return false }
        guard let claudePath = resolveClaude() else { return false }
        lastRefreshAttempt = Date()
        return await withCheckedContinuation { continuation in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: claudePath)
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

    private static func readToken() -> String? {
        switch credentialStore.readClaudeCredentials() {
        case .success(let blob):
            // Access works — remember it and clear any stale denial.
            keychainGranted = true
            keychainDenied = false
            return extractAccessToken(blob)
        case .denied:
            keychainDenied = true
            keychainGranted = false
            return nil
        case .notFound, .failure:
            // Not logged in via CLI / custom API, or transient error.
            return nil
        }
    }

    // MARK: - Helpers

    static func extractAccessToken(_ raw: String) -> String? {
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
