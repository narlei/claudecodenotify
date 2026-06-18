import Foundation

/// Persisted in config.json: secret token (generated once) + onboarding flag +
/// GitHub star-prompt state.
/// Port does NOT go here (it's ephemeral; goes to portFile at each launch).
struct Config: Codable {
    var token: String
    var onboardingShown: Bool
    /// Count of notifications surfaced to the user. Drives the star prompt.
    var notificationsDelivered: Int
    /// Number of times the user chose "Maybe later".
    var starPromptDeferCount: Int
    /// Earliest date the star prompt may reappear after a deferral.
    var starPromptNextEligibleDate: Date?
    /// True once the user starred or exhausted the deferral cap: never show again.
    var starPromptDone: Bool

    // Star prompt tuning.
    static let starPromptThreshold = 30        // notifications before first prompt
    static let starPromptMaxDefers = 3         // "Maybe later" clicks before giving up
    static let starPromptDeferInterval: TimeInterval = 7 * 24 * 60 * 60  // 7 days

    init(token: String, onboardingShown: Bool = false,
         notificationsDelivered: Int = 0, starPromptDeferCount: Int = 0,
         starPromptNextEligibleDate: Date? = nil, starPromptDone: Bool = false) {
        self.token = token
        self.onboardingShown = onboardingShown
        self.notificationsDelivered = notificationsDelivered
        self.starPromptDeferCount = starPromptDeferCount
        self.starPromptNextEligibleDate = starPromptNextEligibleDate
        self.starPromptDone = starPromptDone
    }

    enum CodingKeys: String, CodingKey {
        case token, onboardingShown
        case notificationsDelivered, starPromptDeferCount, starPromptNextEligibleDate, starPromptDone
    }

    // Resilient decode: new fields missing from old config.json don't regenerate the token.
    // Unknown keys (e.g. a legacy donationHidden) are simply ignored.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        token = try c.decode(String.self, forKey: .token)
        onboardingShown = (try? c.decode(Bool.self, forKey: .onboardingShown)) ?? false
        notificationsDelivered = (try? c.decode(Int.self, forKey: .notificationsDelivered)) ?? 0
        starPromptDeferCount = (try? c.decode(Int.self, forKey: .starPromptDeferCount)) ?? 0
        starPromptNextEligibleDate = try? c.decode(Date.self, forKey: .starPromptNextEligibleDate)
        starPromptDone = (try? c.decode(Bool.self, forKey: .starPromptDone)) ?? false
    }

    /// Loads from disk; if not found, generates new token and saves.
    static func loadOrCreate() -> Config {
        let url = AppPaths.configFile
        if let data = try? Data(contentsOf: url),
           let cfg = try? JSONDecoder().decode(Config.self, from: data) {
            return cfg
        }
        let cfg = Config(token: Self.generateToken())
        cfg.save()
        return cfg
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        _ = try? AppPaths.ensureSupportDirectory()
        try? data.write(to: AppPaths.configFile, options: .atomic)
        // config has the token — restrict to 600.
        try? FileManager.default.setAttributes([.posixPermissions: 0o600],
                                               ofItemAtPath: AppPaths.configFile.path)
    }

    /// Marks onboarding as seen and persists.
    mutating func markOnboardingShown() {
        onboardingShown = true
        save()
    }

    // MARK: - Star prompt

    /// Records that a notification was surfaced to the user and persists.
    mutating func recordNotificationDelivered() {
        notificationsDelivered += 1
        save()
    }

    /// True when the star prompt should be shown now: not yet done, enough
    /// notifications delivered, and past any deferral cooldown.
    var isStarPromptEligible: Bool {
        !starPromptDone
            && notificationsDelivered >= Self.starPromptThreshold
            && (starPromptNextEligibleDate == nil || Date() >= starPromptNextEligibleDate!)
    }

    /// The user starred (or otherwise resolved positively): never show again.
    mutating func starPromptCompleted() {
        starPromptDone = true
        save()
    }

    /// The user chose "Maybe later". Bumps the defer count; after the cap we
    /// give up entirely, otherwise we schedule the next eligible date.
    mutating func starPromptDeferred() {
        starPromptDeferCount += 1
        if starPromptDeferCount >= Self.starPromptMaxDefers {
            starPromptDone = true
        } else {
            starPromptNextEligibleDate = Date().addingTimeInterval(Self.starPromptDeferInterval)
        }
        save()
    }

    /// 32 random bytes in base64url (no padding) — secure and shell-friendly.
    private static func generateToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        for i in bytes.indices { bytes[i] = UInt8.random(in: 0...255) }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
