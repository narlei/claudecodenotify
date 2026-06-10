import SwiftUI

/// Observable preferences store — saves to disk on every change.
@MainActor
final class PreferencesStore: ObservableObject {
    @Published var prefs: Preferences {
        didSet { prefs.save() }
    }
    init() { prefs = Preferences.load() }
}

/// Preferences window: behavior when focused + duration and sound per type.
struct PreferencesView: View {
    @StateObject private var store = PreferencesStore()
    @AppStorage("usageBarsEnabled") private var usageBarsEnabled: Bool = true
    @AppStorage("keychainDenied") private var keychainDenied: Bool = false

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            AccountsPrefsView()
                .tabItem { Label("Accounts", systemImage: "person.2") }
        }
        .padding(.top, 14)
        .frame(width: 460, height: 650)
    }

    private var generalTab: some View {
        Form {
            Section("Usage bars") {
                Toggle("Show usage bars", isOn: $usageBarsEnabled)
                if usageBarsEnabled && keychainDenied {
                    HStack {
                        Text("Keychain access was denied. Click to try again.")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Reset") {
                            UsageFetcher.resetKeychainPermission()
                            keychainDenied = false
                        }
                        .buttonStyle(.link)
                    }
                } else {
                    Text("Shows your Claude Code 5h / 7d rate-limit usage in the menu bar and notifications. Requires Claude Code CLI. Disable if you use a custom API.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("When Claude's terminal or editor is focused") {
                Toggle("Show notification card", isOn: $store.prefs.showCardWhenHostFocused)
                Toggle("Play notification sound", isOn: $store.prefs.playSoundWhenHostFocused)
                Text("These settings apply when the app running Claude is already in front. Sound still respects the choice for each notification type.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Claude needs permission") {
                typeRow($store.prefs.permission)
            }
            Section("Claude is idle (waiting for input)") {
                typeRow($store.prefs.idle)
            }
            Section("Claude finished the task") {
                typeRow($store.prefs.stop)
            }
            Section {
                Text("Duration 0 = the notification stays until you dismiss it (Esc/click).")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func typeRow(_ pref: Binding<Preferences.TypePref>) -> some View {
        // Duration
        HStack {
            Text("Time on screen")
            Spacer()
            Text(pref.wrappedValue.durationSeconds == 0
                 ? "until dismissed"
                 : "\(Int(pref.wrappedValue.durationSeconds))s")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Stepper("", value: pref.durationSeconds, in: 0...120, step: 1)
                .labelsHidden()
        }
        // Sound
        HStack {
            Picker("Sound", selection: Binding(
                get: { pref.wrappedValue.soundName ?? "" },
                set: { pref.wrappedValue.soundName = $0.isEmpty ? nil : $0 }
            )) {
                ForEach(Preferences.availableSounds, id: \.self) { name in
                    Text(name.isEmpty ? "None" : name).tag(name)
                }
            }
            Button {
                NotificationSound.play(pref.wrappedValue.soundName)
            } label: {
                Image(systemName: "play.circle")
            }
            .buttonStyle(.borderless)
            .disabled((pref.wrappedValue.soundName ?? "").isEmpty)
            .help("Preview")
        }
    }
}
