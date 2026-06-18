import AppKit
import SwiftUI

/// Receives events from the server and shows the central notification. No buttons: Enter takes to
/// Claude's terminal; Esc/click/timeout closes and restores focus. One at a time (new
/// replaces previous).
@MainActor
final class NotificationService {
    private(set) var config: Config
    private var server: LocalHTTPServer?

    private var panel: NotificationPanel?
    private var previousApp: NSRunningApplication?
    private var currentEvent: NotificationEvent?
    private var currentHostApp: NSRunningApplication?
    private var keyMonitor: Any?
    private var dismissTask: Task<Void, Never>?
    /// Whether the currently shown card stole focus (so auto-dismiss knows to restore it).
    private var stealsFocusCurrent = true

    var onPortChange: ((UInt16) -> Void)?

    init(config: Config) { self.config = config }

    func start() {
        let server = LocalHTTPServer(token: config.token) { [weak self] body, term, pids in
            guard let payload = NotificationPayload.decode(from: body),
                  let event = NotificationEvent(payload: payload, termProgram: term, hostPIDs: pids) else { return }
            Task { @MainActor in self?.present(event) }
        }
        server.onReady = { port in
            Self.writePortFile(port)
            Task { @MainActor in self.onPortChange?(port) }
        }
        do { try server.start(); self.server = server }
        catch { NSLog("ClaudeCodeNotify: failed to start server: \(error)") }
    }

    func stop() { server?.stop(); server = nil }

    // MARK: - Presentation

    private func present(_ event: NotificationEvent) {
        guard event.shouldNotify else { return }

        // Count this delivery and capture star-prompt eligibility BEFORE any
        // branch returns, so the sound-only path also gets a chance to prompt.
        config.recordNotificationDelivered()
        let showStarPrompt = config.isStarPromptEligible

        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let resolvedHostApp = TerminalActivator.resolveHost(pids: event.hostPIDs,
                                                            termProgram: event.termProgram)
        let hostIsFocused = TerminalActivator.isFocused(resolvedHostApp, frontmostApp: frontmostApp)
        let preferences = Preferences.load()
        let pref = preferences.pref(for: event.kind)
        let shouldShowCard = !hostIsFocused || preferences.showCardWhenHostFocused
        let shouldPlaySound = !hostIsFocused || preferences.playSoundWhenHostFocused

        NSLog("ClaudeCodeNotify: notification kind=\(event.kind) proj=\(event.projectName) hostFocused=\(hostIsFocused) card=\(shouldShowCard) sound=\(shouldPlaySound)")

        // Sound without card doesn't change focus or dismiss a visible notification.
        guard shouldShowCard else {
            if shouldPlaySound { NotificationSound.play(pref.soundName) }
            maybeShowStarPrompt(showStarPrompt)
            return
        }

        teardownPanel(restoreFocus: false)      // clears previous without changing focus
        previousApp = frontmostApp
        currentEvent = event

        // The fallback to previous app is only for "go to terminal", never to suppress.
        let hostApp = resolvedHostApp ?? previousApp
        currentHostApp = hostApp

        let stealsFocus = !preferences.dontStealFocus
        stealsFocusCurrent = stealsFocus
        let rootView = NotificationView(
            event: event,
            hostAppName: hostApp?.localizedName,
            dontStealFocus: preferences.dontStealFocus,
            onActivate: { [weak self] in self?.goToTerminal() },
            // Restore focus only when we took it; in non-stealing mode focus never moved.
            onDismiss: { [weak self] in self?.teardownPanel(restoreFocus: stealsFocus) }
        )
        let hosting = FirstMouseHostingView(rootView: rootView)
        hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
        let panel = NotificationPanel(contentView: hosting, stealsFocus: stealsFocus)
        panel.positionTopCenter()
        self.panel = panel

        if stealsFocus {
            // Captures keyboard: activates app and makes panel key (Enter/Esc work).
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            installKeyMonitor()
        } else {
            // Show without stealing focus; clicks are handled inside the card view.
            panel.orderFront(nil)
        }

        if shouldPlaySound { NotificationSound.play(pref.soundName) }
        scheduleAutoDismiss(after: pref.durationSeconds)

        // After the card is set up, so the star window doesn't fight it.
        maybeShowStarPrompt(showStarPrompt)
    }

    /// Presents the GitHub star prompt when eligible, wiring the callbacks back
    /// into config so the prompt state advances (completed / deferred).
    private func maybeShowStarPrompt(_ shouldShow: Bool) {
        guard shouldShow else { return }
        StarPromptWindowController.shared.show(
            onStar: { [weak self] in
                SupportLinks.open(SupportLinks.repoPage)
                self?.config.starPromptCompleted()
            },
            onLater: { [weak self] in
                self?.config.starPromptDeferred()
            }
        )
    }

    private func goToTerminal() {
        TerminalActivator.activate(currentHostApp)
        teardownPanel(restoreFocus: false) // terminal is already activated
    }

    // MARK: - Keyboard monitor

    /// Only used in focus-stealing mode (the panel is key). Clicks are handled inside the card view.
    private func installKeyMonitor() {
        removeMonitors()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self, self.panel != nil else { return e }
            switch e.keyCode {
            case 36, 76:           // Return / Enter from numeric keypad
                self.goToTerminal(); return nil
            case 53:               // Esc
                self.teardownPanel(restoreFocus: true); return nil
            default:
                return e
            }
        }
    }

    private func removeMonitors() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private func scheduleAutoDismiss(after seconds: TimeInterval) {
        dismissTask?.cancel()
        guard seconds > 0 else { return } // 0 = stays until user closes
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                self.teardownPanel(restoreFocus: self.stealsFocusCurrent)
            }
        }
    }

    private func teardownPanel(restoreFocus: Bool) {
        dismissTask?.cancel(); dismissTask = nil
        removeMonitors()
        panel?.orderOut(nil)
        panel = nil
        currentEvent = nil
        currentHostApp = nil
        if restoreFocus { previousApp?.activate(options: [.activateIgnoringOtherApps]) }
    }

    // MARK: - Port file

    private static func writePortFile(_ port: UInt16) {
        _ = try? AppPaths.ensureSupportDirectory()
        let url = AppPaths.portFile
        try? "\(port)\n".data(using: .utf8)?.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
