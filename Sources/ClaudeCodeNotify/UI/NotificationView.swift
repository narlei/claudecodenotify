import SwiftUI

/// Central notification, NO action buttons. Shows what Claude wants + keyboard hint.
struct NotificationView: View {
    let event: NotificationEvent
    var hostAppName: String? = nil

    var previewUsage: UsageData? = nil
    @State private var usage: UsageData? = nil

    var body: some View {
        VStack(spacing: 0) {
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
                        Text(markdown(subtitle))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(8)                                  // up to 8 lines; truncates beyond
                            .fixedSize(horizontal: false, vertical: true)  // grows/shrinks with text
                    }
                    Text("⏎ go to \(hostAppName ?? "Claude")   ·   esc dismiss")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
            .padding(16)

            if let display = usage ?? previewUsage {
                UsageBarsView(usage: display)
            }
        }
        .frame(width: 420)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
        .onAppear {
            if let previewUsage { usage = previewUsage }
        }
        .task {
            guard previewUsage == nil else { return }
            usage = await UsageFetcher.fetch()
        }
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

    /// Parses markdown into an AttributedString, falling back to plain text on failure.
    /// Uses `.full` interpretation so soft line breaks in the message are preserved.
    private func markdown(_ string: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: true,
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: string, options: options))
            ?? AttributedString(string)
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
