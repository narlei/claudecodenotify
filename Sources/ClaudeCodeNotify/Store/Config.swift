import Foundation

/// Persisted in config.json: secret token (generated once) + onboarding flag.
/// Port does NOT go here (it's ephemeral; goes to portFile at each launch).
struct Config: Codable {
    var token: String
    var onboardingShown: Bool

    init(token: String, onboardingShown: Bool = false) {
        self.token = token
        self.onboardingShown = onboardingShown
    }

    enum CodingKeys: String, CodingKey { case token, onboardingShown }

    // Resilient decode: new fields missing from old config.json don't regenerate the token.
    // Unknown keys (e.g. a legacy donationHidden) are simply ignored.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        token = try c.decode(String.self, forKey: .token)
        onboardingShown = (try? c.decode(Bool.self, forKey: .onboardingShown)) ?? false
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
