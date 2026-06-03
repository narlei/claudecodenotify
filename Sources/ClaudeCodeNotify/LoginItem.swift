import Foundation
import ServiceManagement

/// "Abrir no login" via SMAppService (macOS 13+). Só funciona pro .app registrado;
/// no binário de dev pode falhar — tratamos com try? e refletimos o status real.
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
            NSLog("ClaudeCodeNotify: SMAppService falhou: \(error)")
        }
    }
}
