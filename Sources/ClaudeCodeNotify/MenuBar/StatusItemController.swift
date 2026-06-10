import AppKit
import SwiftUI
import UserNotifications

/// Menu bar item: bell icon + menu (connect/disconnect Claude Code, open at login, quit).
@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private var config: Config
    private let profileManager: ProfileManager
    private var token: String { config.token }
    private var menuUsage: UsageData? = nil

    init(config: Config, profileManager: ProfileManager) {
        self.config = config
        self.profileManager = profileManager
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            // Monochrome glyph (template) in native menu bar icon style.
            button.image = IconRenderer.menuBarImage()
                ?? NSImage(systemSymbolName: "bell", accessibilityDescription: "ClaudeCodeNotify")
            button.image?.isTemplate = true
            button.image?.accessibilityDescription = "ClaudeCodeNotify"
            button.imagePosition = .imageLeading
        }
        updateButtonAppearance()

        NotificationCenter.default.addObserver(forName: .ccnotifyProfilesDidChange,
                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.updateButtonAppearance()
                self.rebuildMenu()
                HotKeyCenter.shared.register(profiles: self.profileManager.profiles)
            }
        }

        // When onboarding finishes, pop the menu open so the user sees the app in the menu bar.
        NotificationCenter.default.addObserver(forName: .ccnotifyPopUpMenu,
                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.statusItem.button?.performClick(nil) }
        }

        HotKeyCenter.shared.onHotKey = { [weak self] profileID in
            self?.performSwitch(to: profileID)
        }
        HotKeyCenter.shared.register(profiles: profileManager.profiles)

        profileManager.onUnknownAccountDetected = { [weak self] identity in
            Task { @MainActor in self?.notifyUnknownAccount(identity) }
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()

        // Skip the startup fetch on first launch: the keychain prompt must not appear
        // before the welcome screen. The menu's menuWillOpen will fetch on first open.
        if config.onboardingShown {
            Task {
                profileManager.reconcile()
                if let usage = await profileManager.refreshActiveUsage() {
                    ResetNotificationScheduler.schedule(from: usage)
                }
            }
        }
    }

    /// With ≥2 profiles the active profile's emoji shows next to the bell;
    /// with 0–1 profiles the menu bar looks exactly as before.
    private func updateButtonAppearance() {
        guard let button = statusItem.button else { return }
        if profileManager.isMultiAccount, let active = profileManager.activeProfile {
            button.title = " " + active.emoji
        } else {
            button.title = ""
        }
    }

    // MARK: - Profile switching

    /// Switches profile showing the confirmation card (used by menu items and hotkeys).
    func performSwitch(to profileID: UUID) {
        guard let target = profileManager.profiles.first(where: { $0.id == profileID }),
              target.id != profileManager.activeProfile?.id else { return }
        SwitchCardPresenter.shared.show(profile: target)
        Task {
            do {
                let result = try await profileManager.switchTo(profileID: profileID)
                SwitchCardPresenter.shared.showUsage(result.usage)
                if let usage = result.usage { ResetNotificationScheduler.schedule(from: usage) }
                self.menuUsage = result.usage
            } catch ProfileManager.SwitchError.missingSnapshot {
                SwitchCardPresenter.shared.dismiss()
                notify("Can't switch to \(target.name)",
                       "Stored credentials for this profile are missing. Run `claude /login` with that account, then re-capture the profile in Preferences → Accounts.")
            } catch {
                SwitchCardPresenter.shared.dismiss()
                notify("Failed to switch profile", "\(error)")
            }
        }
    }

    private func rebuildMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()

        let connected = HookInstaller.isInstalled
        let header = menu.addItem(withTitle: connected ? "Claude Code: connected" : "Claude Code: disconnected",
                                  action: nil, keyEquivalent: "")
        header.isEnabled = false
        header.image = statusDot(connected ? .systemGreen : .systemRed)

        if profileManager.isMultiAccount {
            menu.addItem(.separator())
            for profile in profileManager.profiles {
                menu.addItem(profileMenuItem(profile))
            }
        }

        if let usage = menuUsage {
            menu.addItem(.separator())
            let usageItem = NSMenuItem()
            usageItem.isEnabled = false
            let hostingView = NSHostingView(rootView:
                UsageBarsView(usage: usage, horizontalPadding: 17)
                    .frame(width: 260)
                    .environment(\.colorScheme, .dark)
            )
            hostingView.frame = CGRect(origin: .zero, size: hostingView.fittingSize)
            usageItem.view = hostingView
            menu.addItem(usageItem)
        }

        menu.addItem(.separator())
        if connected {
            menu.addItem(withTitle: "Disconnect Claude Code", action: #selector(disconnect), keyEquivalent: "").target = self
        } else {
            menu.addItem(withTitle: "Connect Claude Code", action: #selector(connect), keyEquivalent: "").target = self
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "Welcome…", action: #selector(openWelcome), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",").target = self
        let login = menu.addItem(withTitle: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off

        menu.addItem(.separator())
        let updateTitle = Updater.shared.hasNewVersion ? "Check for Updates… (New version available!)" : "Check for Updates…"
        let updateItem = menu.addItem(withTitle: updateTitle, action: #selector(checkUpdates), keyEquivalent: "")
        updateItem.target = self
        if Updater.shared.hasNewVersion { updateItem.image = statusDot(.systemBlue) }

        if !config.donationHidden {
            menu.addItem(.separator())
            menu.addItem(buildSupportItem())
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q").target = self
    }

    /// Donation submenu ("buy me a coffee"). Hides when user marks "already donated".
    private func buildSupportItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Support ClaudeCodeNotify ☕", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        if let koFi = SupportLinks.koFi {
            let i = sub.addItem(withTitle: "Buy me a coffee (Ko-fi)", action: #selector(openKoFi), keyEquivalent: "")
            i.target = self; i.representedObject = koFi
        }
        if let payPal = SupportLinks.payPal {
            let i = sub.addItem(withTitle: "Donate via PayPal", action: #selector(openPayPal), keyEquivalent: "")
            i.target = self; i.representedObject = payPal
        }
        sub.addItem(withTitle: "Copy Pix key (\(SupportLinks.pixKey))", action: #selector(copyPix), keyEquivalent: "").target = self
        sub.addItem(.separator())
        sub.addItem(withTitle: "I already donated — hide this", action: #selector(hideDonation), keyEquivalent: "").target = self
        item.submenu = sub
        return item
    }

    /// Menu entry for one profile: checkmark on the active one; inactive ones show
    /// their last cached usage as a gray second line.
    private func profileMenuItem(_ profile: Profile) -> NSMenuItem {
        let item = NSMenuItem(title: "\(profile.emoji) \(profile.name)",
                              action: #selector(switchProfileItem(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = profile.id

        if profile.id == profileManager.activeProfile?.id {
            item.state = .on
        } else if let cached = profile.cachedUsage {
            let title = NSMutableAttributedString(
                string: "\(profile.emoji) \(profile.name)\n",
                attributes: [.font: NSFont.menuFont(ofSize: 0)])
            let ago = Self.relativeFormatter.localizedString(for: cached.fetchedAt, relativeTo: Date())
            title.append(NSAttributedString(
                string: "5h \(Int(cached.util5h * 100))% · 7d \(Int(cached.util7d * 100))% · \(ago)",
                attributes: [.font: NSFont.menuFont(ofSize: 11),
                             .foregroundColor: NSColor.secondaryLabelColor]))
            item.attributedTitle = title
        }
        return item
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    @objc private func switchProfileItem(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        performSwitch(to: id)
    }

    /// Reconcile found a manual `claude /login` into an account with no profile.
    /// A system notification (non-modal) suggests capturing it; dedup per account
    /// so reopening the menu doesn't nag.
    private var promptedUnknownAccounts: Set<String> = []

    private func notifyUnknownAccount(_ identity: ClaudeConfigFile.AccountIdentity) {
        let key = "\(identity.email)|\(identity.orgUuid ?? "")"
        guard !promptedUnknownAccounts.contains(key) else { return }
        promptedUnknownAccounts.insert(key)

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "New Claude account detected"
            content.body = "\(identity.email) isn't a profile yet. Open Preferences → Accounts to capture it."
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "ccnotify-unknown-account",
                                      content: content, trigger: nil))
        }
    }

    /// Colored status dot for menu item (green = connected, red = disconnected).
    private func statusDot(_ color: NSColor) -> NSImage? {
        let cfg = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        let img = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)
        img?.isTemplate = false
        return img
    }

    @objc private func openKoFi(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL { SupportLinks.open(url) }
    }

    @objc private func openPayPal(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL { SupportLinks.open(url) }
    }

    @objc private func copyPix() {
        SupportLinks.copyPixKey()
    }

    @objc private func hideDonation() {
        config.hideDonation()
        rebuildMenu()
    }

    @objc private func openWelcome() {
        OnboardingWindowController.shared.show(token: token)
    }

    @objc private func openPreferences() {
        PreferencesWindowController.shared.show()
    }

    @objc private func checkUpdates() {
        Updater.shared.checkForUpdates(explicit: true)
    }

    @objc private func toggleLogin() {
        LoginItem.setEnabled(!LoginItem.isEnabled)
        rebuildMenu()
    }

    @objc private func connect() {
        do {
            try HookInstaller.install(token: token)
            notify("Claude Code connected", "Hooks were installed in ~/.claude/settings.json (a backup was created).")
        } catch {
            notify("Failed to connect", "\(error)")
        }
        rebuildMenu()
    }

    @objc private func disconnect() {
        do {
            try HookInstaller.uninstall()
            notify("Claude Code disconnected", "Hooks were removed from ~/.claude/settings.json (a backup was created).")
        } catch {
            notify("Failed to disconnect", "\(error)")
        }
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func notify(_ title: String, _ body: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.alertStyle = .informational
        // Non-activating: shows without stealing focus indefinitely.
        alert.runModal()
    }
}

extension StatusItemController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        Task {
            let hadUpdate = Updater.shared.hasNewVersion
            await Updater.shared.silentCheck()
            if !hadUpdate && Updater.shared.hasNewVersion {
                await MainActor.run { self.rebuildMenu() }
            }
        }
        Task {
            profileManager.reconcile() // follow out-of-band `claude /login` before fetching
            let usage = await profileManager.refreshActiveUsage()
            if let usage { ResetNotificationScheduler.schedule(from: usage) }
            await MainActor.run {
                self.menuUsage = usage
                self.rebuildMenu()
            }
        }
        rebuildMenu() // reflects actual settings.json state on every open
    }
}
