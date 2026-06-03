import AppKit
import SwiftUI

/// Helper só pro card de teste/spike (título + 2 botões), separado da fila real (RequestQueue).
@MainActor
final class PanelController {
    private var panel: PermissionPanel?

    /// `onDecision(true)` = Allow, `onDecision(false)` = Deny.
    func show(title: String, subtitle: String, onDecision: @escaping (Bool) -> Void) {
        dismiss()
        let card = TestCardView(
            title: title,
            subtitle: subtitle,
            onAllow: { [weak self] in self?.dismiss(); onDecision(true) },
            onDeny: { [weak self] in self?.dismiss(); onDecision(false) }
        )
        let hosting = NSHostingView(rootView: card)
        hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
        let p = PermissionPanel(contentView: hosting)
        p.positionTopCenter()
        p.orderFrontRegardless()
        panel = p
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct TestCardView: View {
    let title: String
    let subtitle: String
    let onAllow: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "bell.badge.fill").font(.title2).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 10) {
                Button(role: .destructive, action: onDeny) { Text("Deny").frame(maxWidth: .infinity) }
                    .keyboardShortcut(.cancelAction)
                Button(action: onAllow) { Text("Allow").frame(maxWidth: .infinity) }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        }
        .padding(18)
        .frame(width: 460)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.08)))
    }
}
