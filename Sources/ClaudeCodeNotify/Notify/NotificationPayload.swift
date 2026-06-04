import Foundation

/// Payload dos hooks Notification/Stop do Claude Code (campos capturados na validação).
struct NotificationPayload: Decodable {
    let hookEventName: String?
    let notificationType: String?
    let message: String?
    let cwd: String?
    let sessionID: String?
    let lastAssistantMessage: String?

    enum CodingKeys: String, CodingKey {
        case hookEventName = "hook_event_name"
        case notificationType = "notification_type"
        case message
        case cwd
        case sessionID = "session_id"
        case lastAssistantMessage = "last_assistant_message"
    }

    static func decode(from data: Data) -> NotificationPayload? {
        try? JSONDecoder().decode(NotificationPayload.self, from: data)
    }
}
