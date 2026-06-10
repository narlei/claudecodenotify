import Foundation

/// Switch engine for multi-account profiles. Owns the ProfileStore and orchestrates:
/// capture (snapshot current account), switch (re-snapshot exiting profile, restore
/// target into Claude's keychain + ~/.claude.json), and reconcile (follow out-of-band
/// `claude /login`). With 0–1 profiles nothing here runs — single-account behavior
/// is untouched.
///
/// All calls are expected from the main thread (menu/hotkey/preferences); usage
/// fetching is injected so tests never hit the network or the real keychain.
extension Notification.Name {
    /// Posted after any persisted profile change (menu, icon and preferences observe it).
    static let ccnotifyProfilesDidChange = Notification.Name("ccnotifyProfilesDidChange")
    /// Posted when the onboarding screen closes, so the menu bar pops open to greet the user.
    static let ccnotifyPopUpMenu = Notification.Name("ccnotifyPopUpMenu")
}

final class ProfileManager {
    /// App-wide instance (AppDelegate, menu, preferences). Tests build their own.
    static let shared = ProfileManager()

    enum CaptureError: Error {
        case notLoggedIn          // no oauthAccount in ~/.claude.json
        case credentialsUnavailable // keychain read failed/denied
    }

    enum SwitchError: Error {
        case unknownProfile
        case missingSnapshot      // profile needs re-capture (run claude /login)
    }

    struct SwitchResult {
        let profile: Profile
        let usage: UsageData?     // nil = fetch failed (possibly needs re-login)
    }

    private(set) var store: ProfileStore
    private let credentials: CredentialStoring
    private let fetchUsage: () async -> UsageData?

    /// Fired when reconcile finds an account that is no profile (offer to create one).
    var onUnknownAccountDetected: ((ClaudeConfigFile.AccountIdentity) -> Void)?

    init(credentials: CredentialStoring = SecurityToolCredentialStore(),
         fetchUsage: @escaping () async -> UsageData? = { await UsageFetcher.fetch() }) {
        self.credentials = credentials
        self.fetchUsage = fetchUsage
        self.store = ProfileStore.load()
    }

    var profiles: [Profile] { store.profiles }
    var activeProfile: Profile? { store.activeProfile }
    /// Multi-account UI (emoji in menu bar, profiles menu section) only appears from 2 profiles on.
    var isMultiAccount: Bool { store.profiles.count >= 2 }

    // MARK: - Capture

    /// Creates a profile from the account currently logged in (keychain + oauthAccount).
    /// If that account is already a profile, refreshes its snapshot instead of duplicating.
    @discardableResult
    func captureCurrentAccount(name: String, emoji: String) throws -> Profile {
        guard let identity = ClaudeConfigFile.readIdentity(),
              let accountJSON = ClaudeConfigFile.readOAuthAccountJSON() else {
            throw CaptureError.notLoggedIn
        }
        guard let blob = credentials.readClaudeCredentials().value else {
            throw CaptureError.credentialsUnavailable
        }

        if var existing = store.profile(matchingEmail: identity.email, orgUuid: identity.orgUuid) {
            try credentials.writeSnapshot(profileID: existing.id, blob: blob)
            existing.oauthAccountJSON = accountJSON
            existing.accountOrgName = identity.orgName
            replace(existing)
            store.activeProfileID = existing.id
            persist()
            return existing
        }

        let profile = Profile(name: name, emoji: emoji,
                              accountEmail: identity.email,
                              accountOrgUuid: identity.orgUuid,
                              accountOrgName: identity.orgName,
                              oauthAccountJSON: accountJSON)
        try credentials.writeSnapshot(profileID: profile.id, blob: blob)
        store.profiles.append(profile)
        store.activeProfileID = profile.id
        persist()
        return profile
    }

    // MARK: - Switch

    /// Switches Claude Code to the given profile. Switching to the already-active
    /// profile is a usage refresh only. Usage fetch failure does not fail the switch.
    func switchTo(profileID: UUID) async throws -> SwitchResult {
        guard let target = store.profiles.first(where: { $0.id == profileID }) else {
            throw SwitchError.unknownProfile
        }
        if target.id == store.activeProfileID {
            return SwitchResult(profile: target, usage: await refreshActiveUsage())
        }

        guard let blob = credentials.readSnapshot(profileID: target.id).value else {
            throw SwitchError.missingSnapshot
        }

        resnapshotActive()
        try credentials.writeClaudeCredentials(blob)
        if !target.oauthAccountJSON.isEmpty {
            try? ClaudeConfigFile.writeOAuthAccountJSON(target.oauthAccountJSON)
        }
        store.activeProfileID = target.id
        persist()

        return SwitchResult(profile: target, usage: await refreshActiveUsage())
    }

    /// The exiting profile keeps the freshest tokens (the CLI may have rotated them
    /// while it was active). Skipped if the keychain doesn't belong to the active
    /// profile (out-of-band login) — never save account A's tokens under profile B.
    private func resnapshotActive() {
        guard let active = store.activeProfile else { return }
        let identity = ClaudeConfigFile.readIdentity()
        guard active.matches(email: identity?.email, orgUuid: identity?.orgUuid) else { return }
        if let blob = credentials.readClaudeCredentials().value {
            try? credentials.writeSnapshot(profileID: active.id, blob: blob)
        }
    }

    // MARK: - Reconcile (out-of-band `claude /login`)

    /// Aligns profile state with reality. If the user logged into a known account
    /// manually, adopt it as active and refresh its snapshot. If the account is
    /// unknown, notify — and never overwrite a login the app doesn't own.
    func reconcile() {
        guard !store.profiles.isEmpty else { return }
        guard let identity = ClaudeConfigFile.readIdentity() else { return }
        if let active = store.activeProfile,
           active.matches(email: identity.email, orgUuid: identity.orgUuid) { return }

        if let known = store.profile(matchingEmail: identity.email, orgUuid: identity.orgUuid) {
            store.activeProfileID = known.id
            if let blob = credentials.readClaudeCredentials().value {
                try? credentials.writeSnapshot(profileID: known.id, blob: blob)
            }
            persist()
        } else {
            onUnknownAccountDetected?(identity)
        }
    }

    // MARK: - Usage

    /// Fetches usage for the active account and caches it on the active profile.
    @discardableResult
    func refreshActiveUsage() async -> UsageData? {
        guard let usage = await fetchUsage() else { return nil }
        if let id = store.activeProfileID,
           let idx = store.profiles.firstIndex(where: { $0.id == id }) {
            store.profiles[idx].cachedUsage = Profile.CachedUsage(
                util5h: usage.util5h, util7d: usage.util7d,
                reset5h: usage.reset5h, reset7d: usage.reset7d,
                fetchedAt: Date())
            persist()
        }
        return usage
    }

    // MARK: - Editing

    /// Updates name/emoji/hotkey of an existing profile.
    func update(_ profile: Profile) {
        replace(profile)
        persist()
    }

    /// Removes the profile and its keychain snapshot. The live Claude keychain entry
    /// is left alone — deleting a profile never logs anyone out.
    func deleteProfile(id: UUID) {
        credentials.deleteSnapshot(profileID: id)
        store.profiles.removeAll { $0.id == id }
        if store.activeProfileID == id { store.activeProfileID = nil }
        persist()
    }

    // MARK: - Internals

    private func replace(_ profile: Profile) {
        guard let idx = store.profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        store.profiles[idx] = profile
    }

    private func persist() {
        store.save()
        NotificationCenter.default.post(name: .ccnotifyProfilesDidChange, object: self)
    }
}
