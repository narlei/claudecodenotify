import Foundation

/// Payload from Claude Code's Notification/Stop hooks (fields captured during validation).
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
