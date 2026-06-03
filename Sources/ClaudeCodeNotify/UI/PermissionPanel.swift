import AppKit

/// NSPanel não-ativante (risco #1 do SPEC): aparece centralizado no topo, por cima de
/// tudo (inclusive fullscreen / qualquer Space) e recebe cliques SEM ativar o app nem
/// roubar o foco do terminal/editor.
final class PermissionPanel: NSPanel {

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 200),
            // .nonactivatingPanel: clicar no painel não ativa o app.
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Não rouba foco: só vira "key" quando um controle realmente precisar (ex.: campo
        // de texto do motivo do Deny). Botões funcionam sem virar key.
        becomesKeyOnlyIfNeeded = true
        isFloatingPanel = true
        hidesOnDeactivate = false
        level = .floating

        // Aparece sobre fullscreen e em qualquer Space.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Visual de card: sem chrome de janela visível.
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        isReleasedWhenClosed = false
        backgroundColor = .clear

        self.contentView = contentView
        setContentSize(contentView.fittingSize)
    }

    // Permite virar key (necessário p/ o campo de motivo); como é nonactivatingPanel,
    // virar key NÃO ativa o app.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Centraliza horizontalmente e posiciona perto do topo da tela ativa.
    func positionTopCenter() {
        guard let screen = targetScreen() else { center(); return }
        let visible = screen.visibleFrame
        let size = frame.size
        let x = visible.midX - size.width / 2
        let topInset: CGFloat = 24
        let y = visible.maxY - size.height - topInset
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func targetScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
    }
}
