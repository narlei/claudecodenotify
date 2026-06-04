import Foundation

/// Um evento de notificação vindo do Claude Code (não bloqueia nada — só avisa).
struct NotificationEvent {
    enum Kind {
        case permission   // Claude precisa de permissão
        case idle         // Claude está ocioso esperando input
        case stop         // Claude terminou a tarefa
        case other        // outros tipos de Notification (ignorados)
    }

    let kind: Kind
    let cwd: String?
    let sessionID: String?
    let message: String?            // mensagem do hook Notification
    let lastAssistantMessage: String? // resumo do Stop
    /// Valor de $TERM_PROGRAM (ex.: "ghostty", "iTerm.app", "Apple_Terminal"), do bridge.
    let termProgram: String?

    var projectName: String {
        guard let cwd, !cwd.isEmpty else { return "" }
        return (cwd as NSString).lastPathComponent
    }

    /// Decide se esse evento merece notificação (filtra tipos irrelevantes).
    var shouldNotify: Bool { kind != .other }

    init?(payload: NotificationPayload, termProgram: String?) {
        self.cwd = payload.cwd
        self.sessionID = payload.sessionID
        self.message = payload.message
        self.lastAssistantMessage = payload.lastAssistantMessage
        self.termProgram = termProgram

        switch payload.hookEventName {
        case "Stop":
            kind = .stop
        case "Notification":
            switch payload.notificationType {
            case "permission_prompt": kind = .permission
            case "idle_prompt":       kind = .idle
            default:                  kind = .other
            }
        default:
            kind = .other
        }
    }
}
