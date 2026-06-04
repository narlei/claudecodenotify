import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private var service: NotificationService?

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
        self.statusItem = StatusItemController(config: config)

        // First launch → welcome screen.
        if !config.onboardingShown {
            OnboardingWindowController.shared.show(token: config.token)
            config.markOnboardingShown()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        service?.stop()
    }
}
