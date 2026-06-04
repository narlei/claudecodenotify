import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private var service: NotificationService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try AppPaths.ensureSupportDirectory()
        } catch {
            NSLog("ClaudeCodeNotify: falha ao criar diretório de suporte: \(error)")
        }

        let config = Config.loadOrCreate()
        let service = NotificationService(config: config)
        service.start()
        self.service = service
        self.statusItem = StatusItemController(token: config.token)
    }

    func applicationWillTerminate(_ notification: Notification) {
        service?.stop()
    }
}
