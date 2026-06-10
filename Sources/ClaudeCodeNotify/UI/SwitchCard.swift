import AppKit
import SwiftUI

/// State of the profile-switch confirmation card: shown immediately on switch,
/// usage bars fill in when the fetch returns.
@MainActor
final class SwitchCardModel: ObservableObject {
    enum UsageState {
        case loading
        case loaded(UsageData)
        case unavailable
    }

    let profile: Profile
    @Published var state: UsageState = .loading

    init(profile: Profile) { self.profile = profile }
}

/// Confirmation card shown after a profile switch. Same visual language as
/// NotificationView, but it never steals focus — the user is mid-keystroke
/// in a terminal when the hotkey fires.
struct SwitchCardView: View {
    @ObservedObject var model: SwitchCardModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                Text(model.profile.emoji)
                    .font(.system(size: 30))
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Switched to \(model.profile.name)")
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(16)

            switch model.state {
            case .loading:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Fetching usage…")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.bottom, 14)
            case .loaded(let usage):
                UsageBarsView(usage: usage)
            case .unavailable:
                Text("Usage unavailable — if this persists, run `claude /login`")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 14)
            }
        }
        .frame(width: 420)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
    }

    private var subtitle: String {
        if let org = model.profile.accountOrgName, !org.isEmpty {
            return "\(model.profile.accountEmail) · \(org)"
        }
        return model.profile.accountEmail
    }
}

/// Presents the switch card in a floating panel without activating the app or
/// becoming key (unlike notification cards, which capture the keyboard on purpose).
@MainActor
final class SwitchCardPresenter {
    static let shared = SwitchCardPresenter()

    private var panel: NotificationPanel?
    private var hosting: NSHostingView<SwitchCardView>?
    private var model: SwitchCardModel?
    private var dismissTask: Task<Void, Never>?
    private var clickMonitor: Any?

    /// Shows the card immediately with a "fetching usage…" placeholder.
    func show(profile: Profile) {
        dismiss()

        let model = SwitchCardModel(profile: profile)
        let hosting = NSHostingView(rootView: SwitchCardView(model: model))
        hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
        let panel = NotificationPanel(contentView: hosting)
        panel.positionTopCenter()
        panel.orderFrontRegardless()   // visible, but no makeKey / no app activation

        self.model = model
        self.hosting = hosting
        self.panel = panel

        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] e in
            guard let self, let panel = self.panel else { return e }
            if e.window == panel { self.dismiss(); return nil }
            return e
        }
        scheduleAutoDismiss(after: 6)
    }

    /// Fills in the fetched usage (nil = fetch failed) and keeps the card up a bit longer.
    func showUsage(_ usage: UsageData?) {
        guard let model, let panel, let hosting else { return }
        model.state = usage.map { .loaded($0) } ?? .unavailable
        // SwiftUI re-layout happens async; resize the borderless panel to match.
        DispatchQueue.main.async {
            panel.setContentSize(hosting.fittingSize)
            panel.positionTopCenter()
        }
        scheduleAutoDismiss(after: 5)
    }

    func dismiss() {
        dismissTask?.cancel(); dismissTask = nil
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
        panel?.orderOut(nil)
        panel = nil
        hosting = nil
        model = nil
    }

    private func scheduleAutoDismiss(after seconds: TimeInterval) {
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }
}
