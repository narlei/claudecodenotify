import SwiftUI

/// Notificação central, SEM botões de ação. Mostra o que o Claude quer + dica de teclado.
struct NotificationView: View {
    let event: NotificationEvent
    var hostAppName: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundStyle(tint)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(8)                                  // até 8 linhas; trunca além
                        .fixedSize(horizontal: false, vertical: true)  // cresce/encolhe com o texto
                }
                Text("⏎ go to \(hostAppName ?? "Claude")   ·   esc dismiss")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 420)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
    }

    private var title: String {
        let proj = event.projectName.isEmpty ? "" : " · \(event.projectName)"
        switch event.kind {
        case .permission: return "Claude needs permission\(proj)"
        case .idle:       return "Claude is waiting for you\(proj)"
        case .stop:       return "Claude finished\(proj)"
        case .other:      return "Claude\(proj)"
        }
    }

    private var subtitle: String? {
        switch event.kind {
        case .permission, .idle: return event.message
        case .stop:              return event.lastAssistantMessage
        case .other:             return event.message
        }
    }

    private var icon: String {
        switch event.kind {
        case .permission: return "lock.shield.fill"
        case .idle:       return "hourglass"
        case .stop:       return "checkmark.circle.fill"
        case .other:      return "bell.fill"
        }
    }

    private var tint: Color {
        switch event.kind {
        case .permission: return .orange
        case .idle:       return .yellow
        case .stop:       return .green
        case .other:      return .accentColor
        }
    }
}
