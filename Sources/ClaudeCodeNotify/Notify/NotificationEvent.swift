import Foundation

/// A notification event from Claude Code (doesn't block anything — just notifies).
struct NotificationEvent {
    enum Kind {
        case permission   // Claude needs permission
        case idle         // Claude is idle waiting for input
        case stop         // Claude finished the task
        case other        // other Notification types (ignored)
    }

    let kind: Kind
    let cwd: String?
    let sessionID: String?
    let message: String?            // message from Notification hook
    let lastAssistantMessage: String? // Stop summary
    /// Value of $TERM_PROGRAM (e.g. "ghostty", "iTerm.app", "Apple_Terminal"), from bridge.
    let termProgram: String?
    /// Ancestor PIDs chain from bridge (to find and activate the host GUI app).
    let hostPIDs: [Int32]

    var projectName: String {
        guard let cwd, !cwd.isEmpty else { return "" }
        return (cwd as NSString).lastPathComponent
    }

    /// Decides if this event deserves notification (filters irrelevant types).
    var shouldNotify: Bool { kind != .other }

    init?(payload: NotificationPayload, termProgram: String?, hostPIDs: [Int32]) {
        self.cwd = payload.cwd
        self.sessionID = payload.sessionID
        self.message = payload.message
        self.lastAssistantMessage = payload.lastAssistantMessage
        self.termProgram = termProgram
        self.hostPIDs = hostPIDs

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
