import AppKit
import SwiftUI

/// Dev: renderiza as variações de notificação num PNG pra inspeção de layout.
/// Uso: `ClaudeCodeNotify --render-notif /caminho.png`
@MainActor
enum NotificationRenderer {
    static func render(to path: String) {
        let samples: [(NotificationEvent, String)] = [
            (sample(event: "Notification", type: "permission_prompt", msg: "Claude needs your permission", last: nil), "Ghostty"),
            (sample(event: "Notification", type: "idle_prompt", msg: "Claude is waiting for your input", last: nil), "Cursor"),
            (sample(event: "Stop", type: nil, msg: nil, last: "Done — refactored the auth module, added retries, and the full test suite is green."), "iTerm2")
        ].compactMap { ev, host in ev.map { ($0, host) } }

        let stack = VStack(spacing: 16) {
            ForEach(Array(samples.enumerated()), id: \.offset) { _, pair in
                NotificationView(event: pair.0, hostAppName: pair.1)
            }
        }
        .padding(28)
        .background(
            LinearGradient(colors: [Color(white: 0.13), Color(white: 0.07)],
                           startPoint: .top, endPoint: .bottom)
        )
        .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: stack)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let bmp = NSBitmapImageRep(data: tiff),
              let png = bmp.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
        print("notificações renderizadas em \(path)")
    }

    private static func sample(event: String, type: String?, msg: String?, last: String?) -> NotificationEvent? {
        var dict: [String: Any] = ["hook_event_name": event, "cwd": "/Users/narlei/Sources/MyProject"]
        if let type { dict["notification_type"] = type }
        if let msg { dict["message"] = msg }
        if let last { dict["last_assistant_message"] = last }
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let payload = NotificationPayload.decode(from: data) else { return nil }
        return NotificationEvent(payload: payload, termProgram: "ghostty", hostPIDs: [])
    }
}
