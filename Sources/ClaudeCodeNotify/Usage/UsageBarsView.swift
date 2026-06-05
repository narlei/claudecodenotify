import SwiftUI

struct UsageBarsView: View {
    let usage: UsageData
    var horizontalPadding: CGFloat = 16

    var body: some View {
        VStack(spacing: 6) {
            Divider().opacity(0.3)
            UsageBarRow(label: "5h", util: usage.util5h, reset: usage.reset5h)
            UsageBarRow(label: "7d", util: usage.util7d, reset: usage.reset7d)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, 14)
        .padding(.top, 6)
    }
}

private struct UsageBarRow: View {
    let label: String
    let util: Double
    let reset: Date?

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .leading)

            Canvas { ctx, size in
                let track = Path(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height), cornerRadius: 2)
                ctx.fill(track, with: .color(.white.opacity(0.1)))
                let fill = Path(roundedRect: CGRect(x: 0, y: 0, width: size.width * util, height: size.height), cornerRadius: 2)
                ctx.fill(fill, with: .color(barColor.opacity(0.55)))
            }
            .frame(height: 4)

            Text("\(Int(util * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)

            if let reset {
                Text(formatReset(reset))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 32, alignment: .trailing)
            }
        }
    }

    private var barColor: Color {
        switch util {
        case ..<0.5:  return .green
        case ..<0.75: return .yellow
        case ..<0.9:  return .orange
        default:      return .red
        }
    }

    private func formatReset(_ date: Date) -> String {
        let diff = date.timeIntervalSinceNow
        guard diff > 0 else { return "now" }
        let m = Int(diff / 60)
        if m < 60 { return "\(m)m" }
        let h = Int(diff / 3600)
        if h < 48 { return "\(h)h" }
        return "\(Int(diff / 86400))d"
    }
}
