import Foundation

/// One Claude account the user can switch to. Metadata only — credential snapshots
/// live in the app's own keychain entries (see CredentialStore), never on disk.
struct Profile: Codable, Identifiable, Equatable {
    /// Global hotkey (Carbon key code + Carbon modifier mask).
    struct Hotkey: Codable, Equatable {
        var keyCode: UInt32
        var modifiers: UInt32
    }

    /// Last usage seen for this account, shown grayed-out in the menu while inactive.
    struct CachedUsage: Codable, Equatable {
        var util5h: Double
        var util7d: Double
        var reset5h: Date?
        var reset7d: Date?
        var fetchedAt: Date
    }

    let id: UUID
    var name: String
    var emoji: String

    /// Account identity, from oauthAccount in ~/.claude.json at capture time.
    var accountEmail: String
    var accountOrgUuid: String?
    var accountOrgName: String?

    /// Full oauthAccount object (opaque JSON), restored into ~/.claude.json on switch.
    /// Contains identity/billing metadata, no tokens.
    var oauthAccountJSON: Data

    var hotkey: Hotkey?
    var cachedUsage: CachedUsage?

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, accountEmail, accountOrgUuid, accountOrgName
        case oauthAccountJSON, hotkey, cachedUsage
    }

    init(id: UUID = UUID(), name: String, emoji: String,
         accountEmail: String, accountOrgUuid: String?, accountOrgName: String?,
         oauthAccountJSON: Data, hotkey: Hotkey? = nil, cachedUsage: CachedUsage? = nil) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.accountEmail = accountEmail
        self.accountOrgUuid = accountOrgUuid
        self.accountOrgName = accountOrgName
        self.oauthAccountJSON = oauthAccountJSON
        self.hotkey = hotkey
        self.cachedUsage = cachedUsage
    }

    // Resilient decode: optional fields added later must not drop existing profiles.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        emoji = (try? c.decode(String.self, forKey: .emoji)) ?? "👤"
        accountEmail = try c.decode(String.self, forKey: .accountEmail)
        accountOrgUuid = try? c.decode(String.self, forKey: .accountOrgUuid)
        accountOrgName = try? c.decode(String.self, forKey: .accountOrgName)
        oauthAccountJSON = (try? c.decode(Data.self, forKey: .oauthAccountJSON)) ?? Data()
        hotkey = try? c.decode(Hotkey.self, forKey: .hotkey)
        cachedUsage = try? c.decode(CachedUsage.self, forKey: .cachedUsage)
    }

    /// True when this profile is the given account (org-aware: same email may exist
    /// in a personal and an enterprise org).
    func matches(email: String?, orgUuid: String?) -> Bool {
        guard let email else { return false }
        return accountEmail == email && accountOrgUuid == orgUuid
    }
}

/// profiles.json: profile list + which one is active.
struct ProfileStore: Codable {
    var profiles: [Profile]
    var activeProfileID: UUID?

    static let empty = ProfileStore(profiles: [], activeProfileID: nil)

    enum CodingKeys: String, CodingKey { case profiles, activeProfileID }

    init(profiles: [Profile], activeProfileID: UUID?) {
        self.profiles = profiles
        self.activeProfileID = activeProfileID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profiles = (try? c.decode([Profile].self, forKey: .profiles)) ?? []
        activeProfileID = try? c.decode(UUID.self, forKey: .activeProfileID)
    }

    var activeProfile: Profile? {
        profiles.first { $0.id == activeProfileID }
    }

    func profile(matchingEmail email: String?, orgUuid: String?) -> Profile? {
        profiles.first { $0.matches(email: email, orgUuid: orgUuid) }
    }

    static func load() -> ProfileStore {
        guard let data = try? Data(contentsOf: AppPaths.profilesFile),
              let store = try? JSONDecoder().decode(ProfileStore.self, from: data) else {
            return .empty
        }
        return store
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        _ = try? AppPaths.ensureSupportDirectory()
        try? data.write(to: AppPaths.profilesFile, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600],
                                               ofItemAtPath: AppPaths.profilesFile.path)
    }
}
