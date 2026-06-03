import AppKit
import SwiftUI

/// Fila serial de pedidos: um card por vez. Dedup por tool_use_id (entregas duplicadas
/// compartilham o mesmo card e recebem a mesma decisão). Multi-sessão: o badge mostra
/// quantos estão na fila; cada card identifica o projeto pelo cwd.
@MainActor
final class RequestQueue {
    private struct Entry {
        let request: PermissionRequest
        var waiters: [(CardDecision) -> Void]
    }

    private var entries: [Entry] = []
    private var panel: PermissionPanel?

    /// Notifica o tamanho da fila (pro ícone da menu bar — passo 7).
    var onCountChange: ((Int) -> Void)?

    func enqueue(_ request: PermissionRequest, decision: @escaping (CardDecision) -> Void) {
        if let idx = entries.firstIndex(where: { $0.request.id == request.id }) {
            entries[idx].waiters.append(decision)  // dedup: mesma tool_use_id
            return
        }
        entries.append(Entry(request: request, waiters: [decision]))
        onCountChange?(entries.count)
        if entries.count == 1 { presentFront() }
    }

    // MARK: - Apresentação

    private func presentFront() {
        guard let front = entries.first else { dismiss(); return }

        let card = PermissionCardView(
            request: front.request,
            queueCount: entries.count,
            onDecision: { [weak self] decision in self?.resolveFront(decision) }
        )
        let hosting = NSHostingView(rootView: card)
        hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)

        if let panel {
            panel.contentView = hosting
            panel.setContentSize(hosting.fittingSize)
            panel.positionTopCenter()
            panel.orderFrontRegardless()
        } else {
            let p = PermissionPanel(contentView: hosting)
            p.positionTopCenter()
            p.orderFrontRegardless()
            panel = p
        }
    }

    private func resolveFront(_ decision: CardDecision) {
        guard !entries.isEmpty else { return }
        let entry = entries.removeFirst()
        entry.waiters.forEach { $0(decision) }
        onCountChange?(entries.count)
        presentFront()  // próximo da fila, ou dismiss se vazia
    }

    private func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}
