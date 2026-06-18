import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private var service: NotificationService?
    private var profileManager: ProfileManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try AppPaths.ensureSupportDirectory()
        } catch {
            NSLog("ClaudeCodeNotify: failed to create support directory: \(error)")
        }

        var config = Config.loadOrCreate()
        let service = NotificationService(config: config)
        service.start()
        self.service = service
        let profileManager = ProfileManager.shared
        self.profileManager = profileManager
        self.statusItem = StatusItemController(config: config, profileManager: profileManager)

        // First launch → welcome screen (no close button; only exit is "Get Started").
        if !config.onboardingShown {
            OnboardingWindowController.shared.show(token: config.token, isFirstLaunch: true)
            config.markOnboardingShown()
        }

        // Dev preview: `CCNOTIFY_STAR_PROMPT_PREVIEW=1 make run` shows the star
        // prompt at launch so its look can be checked without hitting the
        // notification threshold. Buttons here are side-effect free (no persisted
        // state) — "Star" just opens the repo. Never fires for end users.
        if ProcessInfo.processInfo.environment["CCNOTIFY_STAR_PROMPT_PREVIEW"] != nil {
            StarPromptWindowController.shared.show(
                onStar: { SupportLinks.open(SupportLinks.repoPage) },
                onLater: {}
            )
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        service?.stop()
    }
}
