import AppKit
import SwiftUI

/// Observable bridge between SwiftUI and ProfileManager for the Accounts tab.
/// Also polls ~/.claude.json while the tab is visible so a `claude /login` done
/// in a terminal shows up as a "new account detected" banner within seconds.
@MainActor
final class AccountsModel: ObservableObject {
    @Published var profiles: [Profile] = []
    @Published var activeID: UUID?
    @Published var detectedNewAccount: ClaudeConfigFile.AccountIdentity?
    @Published var lastError: String?

    let manager: ProfileManager
    private var observer: Any?
    private var pollTask: Task<Void, Never>?

    init(manager: ProfileManager) {
        self.manager = manager
        reload()
        observer = NotificationCenter.default.addObserver(
            forName: .ccnotifyProfilesDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        pollTask?.cancel()
    }

    func reload() {
        profiles = manager.profiles
        activeID = manager.activeProfile?.id
        refreshDetection()
    }

    /// Identity in ~/.claude.json that isn't a profile yet (capture candidate).
    private func refreshDetection() {
        guard let identity = ClaudeConfigFile.readIdentity() else {
            detectedNewAccount = nil
            return
        }
        let known = manager.store.profile(matchingEmail: identity.email, orgUuid: identity.orgUuid)
        detectedNewAccount = known == nil ? identity : nil
    }

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refreshDetection()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func capture(name: String, emoji: String) {
        do {
            try manager.captureCurrentAccount(name: name, emoji: emoji)
            lastError = nil
        } catch ProfileManager.CaptureError.notLoggedIn {
            lastError = "No Claude Code login found. Run `claude /login` first."
        } catch ProfileManager.CaptureError.credentialsUnavailable {
            lastError = "Couldn't read Claude Code credentials from the keychain."
        } catch {
            lastError = "Capture failed: \(error)"
        }
    }

    func save(_ profile: Profile) {
        manager.update(profile)
    }

    /// Sets/clears a hotkey, registering immediately to surface conflicts.
    func setHotkey(_ hotkey: Profile.Hotkey?, for profile: Profile) {
        var updated = profile
        updated.hotkey = hotkey
        manager.update(updated)
        let failed = HotKeyCenter.shared.register(profiles: manager.profiles)
        if failed.contains(profile.id) {
            updated.hotkey = nil
            manager.update(updated)
            lastError = "That shortcut is already in use by another app. Pick a different one."
        } else {
            lastError = nil
        }
    }

    func delete(_ profile: Profile) {
        manager.deleteProfile(id: profile.id)
    }
}

/// Preferences → Accounts: capture, rename, hotkey and delete profiles.
struct AccountsPrefsView: View {
    @StateObject private var model: AccountsModel
    @State private var newName: String = ""
    @State private var newEmoji: String = "🏠"
    @State private var profilePendingDeletion: Profile?

    init(manager: ProfileManager = .shared) {
        _model = StateObject(wrappedValue: AccountsModel(manager: manager))
    }

    var body: some View {
        Form {
            if let error = model.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("Profiles") {
                if model.profiles.isEmpty {
                    Text("No profiles yet. Capture the account you're logged into below — then run `claude /login` with another account and capture it too. Switch instantly via menu or hotkey.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(model.profiles) { profile in
                    ProfileRow(profile: profile,
                               hotkey: profile.hotkey,
                               isActive: profile.id == model.activeID,
                               onSave: { model.save($0) },
                               onHotkey: { model.setHotkey($0, for: profile) },
                               onDelete: { profilePendingDeletion = profile })
                }
            }

            Section("Add account") {
                if let detected = model.detectedNewAccount {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New account detected: **\(detected.email)**")
                            .font(.caption)
                        if let org = detected.orgName, !org.isEmpty {
                            Text(org)
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 8) {
                            TextField("", text: $newEmoji, prompt: Text("🙂"))
                                .labelsHidden()
                                .multilineTextAlignment(.center)
                                .frame(width: 40)
                            TextField("", text: $newName, prompt: Text("Profile name"))
                                .labelsHidden()
                            Button("Capture") {
                                let name = newName.isEmpty ? detected.email : newName
                                model.capture(name: name, emoji: newEmoji.isEmpty ? "👤" : newEmoji)
                                newName = ""
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                    }
                    .padding(.vertical, 2)
                } else if model.profiles.isEmpty {
                    Text("Waiting for a Claude Code login…")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("All set. To add another account, run `claude /login` in a terminal and log into it — it will be detected here automatically.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { model.startPolling() }
        .onDisappear { model.stopPolling() }
        .confirmationDialog("Delete profile \"\(profilePendingDeletion?.name ?? "")\"?",
                            isPresented: Binding(get: { profilePendingDeletion != nil },
                                                 set: { if !$0 { profilePendingDeletion = nil } })) {
            Button("Delete", role: .destructive) {
                if let profile = profilePendingDeletion { model.delete(profile) }
                profilePendingDeletion = nil
            }
        } message: {
            Text("This removes the stored credentials snapshot. It does not log the account out — you can re-capture it anytime.")
        }
    }
}

private struct ProfileRow: View {
    // @State copies the profile once for text editing; hotkey comes in as a plain
    // prop so the recorder always reflects the persisted value after a change.
    @State var profile: Profile
    let hotkey: Profile.Hotkey?
    let isActive: Bool
    let onSave: (Profile) -> Void
    let onHotkey: (Profile.Hotkey?) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                TextField("", text: $profile.emoji)
                    .labelsHidden()
                    .multilineTextAlignment(.center)
                    .frame(width: 40)
                    .onSubmit { onSave(profile) }
                TextField("", text: $profile.name, prompt: Text("Name"))
                    .labelsHidden()
                    .onSubmit { onSave(profile) }
                if isActive {
                    Text("active")
                        .font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.green.opacity(0.2)))
                        .foregroundStyle(.green)
                }
                Spacer()
                HotkeyRecorder(hotkey: hotkey, onChange: onHotkey)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete profile")
            }
            Text(profile.accountOrgName.map { "\(profile.accountEmail) · \($0)" } ?? profile.accountEmail)
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

/// Click → "Press shortcut…" → next keyDown with a modifier becomes the hotkey.
/// Esc cancels, Delete/Backspace clears.
private struct HotkeyRecorder: View {
    let hotkey: Profile.Hotkey?
    let onChange: (Profile.Hotkey?) -> Void

    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button(label) {
            recording ? stopRecording() : startRecording()
        }
        .font(.caption.monospaced())
        .onDisappear { stopRecording() }
    }

    private var label: String {
        if recording { return "Press shortcut…" }
        return hotkey?.display ?? "Record Shortcut"
    }

    private func startRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            defer { stopRecording() }
            switch event.keyCode {
            case 53: // Esc — cancel
                return nil
            case 51, 117: // Delete / Forward Delete — clear
                onChange(nil)
                return nil
            default:
                let mods = Profile.Hotkey.carbonModifiers(from: event.modifierFlags)
                guard mods != 0 else { return nil } // require at least one modifier
                onChange(Profile.Hotkey(keyCode: UInt32(event.keyCode), modifiers: mods))
                return nil
            }
        }
    }

    private func stopRecording() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
