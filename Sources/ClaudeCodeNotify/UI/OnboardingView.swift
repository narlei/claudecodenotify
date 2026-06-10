import SwiftUI

/// Welcome screen (first launch). Explains the app and lets you connect/configure right here.
/// Layout: wide window, 6 feature cards in a 3×2 grid, actions at the bottom.
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
            // ── Header ──────────────────────────────────────────────────
            header

            Divider()

            // ── Feature cards grid ───────────────────────────────────────
            featureGrid
                .padding(.horizontal, 24)
                .padding(.vertical, 20)

            Divider()

            // ── Actions ─────────────────────────────────────────────────
            actions
        }
        .frame(width: 740)
        // Hook prompt
        .alert("Install Claude Code hook?", isPresented: $showHookPrompt) {
            Button("Install") {
                try? HookInstaller.install(token: token)
                connected = HookInstaller.isInstalled
                proceedAfterHookStep()
            }
            Button("Skip", role: .cancel) { proceedAfterHookStep() }
        } message: {
            Text("The hook is what lets ClaudeCodeNotify know when Claude needs your attention. Without it you won't receive any notifications — you can always install it later from the menu bar.")
        }
        // Keychain prompt
        .alert("Allow keychain access?", isPresented: $showKeychainPrompt) {
            Button("Allow") {
                Task {
                    let granted = await UsageFetcher.fetch() != nil
                    keychainGranted = granted
                    onClose()
                }
            }
            Button("Skip", role: .cancel) { onClose() }
        } message: {
            Text("Grants access to your Claude Code credentials so the app can show your 5h and 7d rate-limit usage in the menu bar and on each notification.\n\nWhen macOS asks, choose Always Allow so it works silently from then on. You can enable this later in Preferences.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)

            Text("Welcome to ClaudeCodeNotify")
                .font(.title2.bold())

            Text("Desktop notifications when Claude Code needs you — and one keystroke back to your terminal.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    // MARK: - Feature cards grid (3 columns × 2 rows)

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    private var featureGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            FeatureCard(
                icon: "bell.badge.fill",
                color: .orange,
                title: "Get notified",
                description: "A floating notification appears when Claude asks for permission, goes idle, or finishes a task."
            )
            FeatureCard(
                icon: "return",
                color: .blue,
                title: "Jump back instantly",
                description: "Press Enter on a notification to bring the terminal where Claude is running to the front."
            )
            FeatureCard(
                icon: "menubar.arrow.up.rectangle",
                color: .purple,
                title: "Lives in your menu bar",
                description: "Look for the bell icon at the top-right. Click it for Connect, Preferences, and Open at Login."
            )
            FeatureCard(
                icon: "slider.horizontal.3",
                color: .green,
                title: "Make it yours",
                description: "Set how long each notification stays and which sound it plays (or none) in Preferences."
            )
            FeatureCard(
                icon: "chart.bar.fill",
                color: .cyan,
                title: "Live usage bars",
                description: "Each notification shows your 5-hour and weekly usage at a glance. Requires Claude Code CLI and keychain access."
            )
            FeatureCard(
                icon: "person.2.fill",
                color: .indigo,
                title: "Multi-account",
                description: "Capture multiple Claude accounts as profiles and switch instantly from the menu bar or a global hotkey."
            )
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 14) {

            // Title + 3 steps side by side
            HStack(alignment: .top, spacing: 0) {
                Text("Next Steps")
                    .font(.headline)
                Spacer()
            }

            HStack(alignment: .top, spacing: 1) {
                // Step 1 — Connect Claude Code
                StepColumn(number: 1, done: connected) {
                    Button {
                        if !connected {
                            try? HookInstaller.install(token: token)
                            connected = HookInstaller.isInstalled
                        }
                    } label: {
                        Label(
                            connected ? "Claude Code connected" : "Connect Claude Code",
                            systemImage: connected ? "checkmark.circle.fill" : "link"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .controlSize(.regular)
                    .buttonStyle(.borderedProminent)
                    .tint(connected ? .green : .accentColor)
                    .disabled(connected)
                } caption: {
                    Text(connected
                         ? "Hooks installed in ~/.claude/settings.json (a backup was created)."
                         : "Installs the hooks so Claude Code can notify this app. Reversible anytime from the menu.")
                }

                Divider()

                // Step 2 — Grant keychain
                StepColumn(number: 2, done: keychainGranted) {
                    Group {
                        if keychainGranted {
                            Button {
                                // already granted, disabled
                            } label: {
                                Label("Keychain access granted", systemImage: "checkmark.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .controlSize(.regular)
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .disabled(true)
                        } else {
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
                                    keychainDenied ? "Reset keychain access" : "Grant keychain access",
                                    systemImage: keychainDenied ? "arrow.counterclockwise" : "key.fill"
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .controlSize(.regular)
                            .buttonStyle(.bordered)
                            .tint(keychainDenied ? .orange : .cyan)
                        }
                    }
                } caption: {
                    Group {
                        if keychainDenied {
                            Text("You previously denied access. Click above to try again, then choose ")
                            + Text("Always Allow").bold()
                            + Text(" on the keychain prompt.")
                        } else {
                            Text("Click ")
                            + Text("Always Allow").bold()
                            + Text(" on the keychain prompt so usage bars work silently. Requires Claude Code CLI.")
                        }
                    }
                }

                Divider()

                // Step 3 — Open at login
                StepColumn(number: 3, done: loginEnabled) {
                    Toggle("Open at login", isOn: $loginEnabled)
                        .toggleStyle(.switch)
                        .onChange(of: loginEnabled) { newValue in LoginItem.setEnabled(newValue) }
                } caption: {
                    Text("Launch automatically when you log in so you never miss a notification.")
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            Divider()

            // Get Started
            Button("Get Started", action: handleGetStarted)
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }

    // MARK: - Get Started flow

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

// MARK: - Step Column

/// A numbered step column for side-by-side use inside an HStack.
/// Badge on top → action → caption below.
private struct StepColumn<Action: View, Caption: View>: View {
    let number: Int
    let done: Bool
    @ViewBuilder let action: () -> Action
    @ViewBuilder let caption: () -> Caption

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Badge
            ZStack {
                Circle()
                    .fill(done ? Color.green : Color.accentColor)
                    .frame(width: 24, height: 24)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            action()

            caption()
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Feature Card

private struct FeatureCard: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }
}
