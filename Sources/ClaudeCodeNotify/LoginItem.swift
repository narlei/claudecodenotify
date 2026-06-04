import Foundation
import ServiceManagement

/// "Open at login" via SMAppService (macOS 13+). Only works for the registered .app;
/// in dev binary it may fail — handled with try? and reflects real status.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("ClaudeCodeNotify: SMAppService failed: \(error)")
        }
    }
}
