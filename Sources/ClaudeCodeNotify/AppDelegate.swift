import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private var service: PermissionService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try AppPaths.ensureSupportDirectory()
        } catch {
            NSLog("ClaudeCodeNotify: falha ao criar diretório de suporte: \(error)")
        }

        let config = Config.loadOrCreate()
        let service = PermissionService(config: config)
        let statusItem = StatusItemController(token: config.token)
        service.onQueueCountChange = { [weak statusItem] count in
            statusItem?.updateBadge(count: count)
        }
        service.start()
        self.service = service
        self.statusItem = statusItem

        if CommandLine.arguments.contains("--spike") {
            SpikeFocusTest.run()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        service?.stop()
    }
}
