import SwiftUI

/// Welcome screen (first launch). Explains the app and lets you connect/configure right here.
struct OnboardingView: View {
    let token: String
    let onClose: () -> Void

    @State private var connected = HookInstaller.isInstalled
    @State private var loginEnabled = LoginItem.isEnabled
    @State private var keychainGranted = false
    @AppStorage("keychainDenied") private var keychainDenied: Bool = false

    // Sequential confirmation prompts shown when Get Started is tapped
    // without having completed hook install or keychain grant.
    @State private var showHookPrompt = false
    @State private var showKeychainPrompt = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            features
            Divider()
            actions
        }
        .frame(width: 480)
        // Hook prompt: shown when user taps Get Started without installing the hook.
        .alert("Install Claude Code hook?", isPresented: $showHookPrompt) {
            Button("Install") {
                try? HookInstaller.install(token: token)
                connected = HookInstaller.isInstalled
                proceedAfterHookStep()
            }
            Button("Skip", role: .cancel) {
                proceedAfterHookStep()
            }
        } message: {
            Text("The hook is what lets ClaudeCodeNotify know when Claude needs your attention. Without it you won't receive any notifications — you can always install it later from the menu bar.")
        }
        // Keychain prompt: shown after hook step when keychain access wasn't granted.
        .alert("Allow keychain access?", isPresented: $showKeychainPrompt) {
            Button("Allow") {
                Task {
                    let granted = await UsageFetcher.fetch() != nil
                    keychainGranted = granted
                    onClose()
                }
            }
            Button("Skip", role: .cancel) {
                onClose()
            }
        } message: {
            Text("Grants access to your Claude Code credentials so the app can show your 5h and 7d rate-limit usage in the menu bar and on each notification.\n\nWhen macOS asks, choose Always Allow so it works silently from then on. You can enable this later in Preferences.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 84, height: 84)
            Text("Welcome to ClaudeCodeNotify")
                .font(.title2.bold())
            Text("Desktop notifications when Claude Code needs you — and one keystroke back to your terminal.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .padding(.bottom, 20)
    }

    // MARK: - Features

    private var features: some View {
        VStack(alignment: .leading, spacing: 18) {
            feature("bell.badge.fill", .orange, "Get notified",
                    "A floating notification appears when Claude asks for permission, goes idle waiting for input, or finishes a task.")
            feature("return", .blue, "Jump back instantly",
                    "Press Enter on a notification and it brings the terminal where Claude is running (Ghostty, iTerm, Terminal, Cursor…) to the front.")
            feature("menubar.arrow.up.rectangle", .purple, "Lives in your menu bar",
                    "Look for the bell icon at the top-right. Click it for Connect/Disconnect, Preferences and Open at Login.")
            feature("slider.horizontal.3", .green, "Make it yours",
                    "Set how long each notification stays and which sound it plays (or none) in Preferences.")
            featureUsage
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
    }

    private var featureUsage: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 22))
                .foregroundStyle(.cyan)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text("Live usage bars").font(.headline)
                (Text("Each notification shows your Claude Code 5-hour and weekly usage at a glance. ")
                    + Text("Requires Claude Code CLI installed").bold()
                    + Text(" and keychain access."))
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    NSWorkspace.shared.open(URL(string: "https://code.claude.com/docs/en/quickstart#step-1-install-claude-code")!)
                } label: {
                    Label("Install Claude Code CLI", systemImage: "arrow.up.right")
                        .font(.caption)
                }
                .buttonStyle(.link)
            }
            Spacer(minLength: 0)
        }
    }

    private func feature(_ icon: String, _ color: Color, _ title: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(color)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(desc).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 14) {
            Button {
                if !connected {
                    try? HookInstaller.install(token: token)
                    connected = HookInstaller.isInstalled
                }
            } label: {
                Label(connected ? "Claude Code connected" : "Connect Claude Code",
                      systemImage: connected ? "checkmark.circle.fill" : "link")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(connected ? .green : .accentColor)
            .disabled(connected)

            Text(connected
                 ? "Hooks installed in ~/.claude/settings.json (a backup was created)."
                 : "Installs the hooks so Claude Code can notify this app. Reversible anytime from the menu.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Toggle("Open at login", isOn: $loginEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: loginEnabled) { newValue in LoginItem.setEnabled(newValue) }
                Spacer()
                Button("Open Preferences…") { PreferencesWindowController.shared.show() }
            }

            Divider()

            Button {
                if keychainDenied {
                    UsageFetcher.resetKeychainPermission()
                    keychainDenied = false
                }
                Task {
                    let granted = await UsageFetcher.fetch() != nil
                    keychainGranted = granted
                }
            } label: {
                Label(
                    keychainGranted  ? "Keychain access granted"
                    : keychainDenied ? "Reset keychain access"
                                     : "Grant keychain access for usage bars",
                    systemImage: keychainGranted ? "checkmark.circle.fill"
                               : keychainDenied  ? "arrow.counterclockwise"
                                                 : "key.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.bordered)
            .tint(keychainGranted ? .green : keychainDenied ? .orange : .cyan)
            .disabled(keychainGranted)

            Group {
                if keychainDenied {
                    Text("You previously denied access. Click above to try again, then choose ")
                    + Text("Always Allow").bold()
                    + Text(" on the keychain prompt.")
                } else {
                    Text("Click ")
                    + Text("Always Allow").bold()
                    + Text(" on the keychain prompt so usage bars work silently from then on. Requires Claude Code CLI to be installed.")
                }
            }
            .font(.caption).foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Button("Get Started", action: handleGetStarted)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
        }
        .padding(28)
    }

    // MARK: - Get Started flow

    /// Entry point for the Get Started button. Prompts for anything the user skipped,
    /// then closes. Each step resolves before the next one appears.
    private func handleGetStarted() {
        if !connected {
            showHookPrompt = true
        } else {
            proceedAfterHookStep()
        }
    }

    private func proceedAfterHookStep() {
        let needsKeychain = !keychainGranted
                         && !keychainDenied
                         && UsageFetcher.usageBarsEnabled
        if needsKeychain {
            showKeychainPrompt = true
        } else {
            onClose()
        }
    }
}
