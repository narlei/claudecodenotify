import AppKit

/// Teste de foco do risco #1 (rodado com `--spike`): traz o TextEdit pra frente, mostra o
/// card SEM ativar o app, e loga o estado de foco antes/depois — provando que o painel não
/// rouba o foco. Loga também as coordenadas globais (top-left, em pontos) do botão Allow,
/// pra um clique externo real poder ser disparado em cima dele.
@MainActor
enum SpikeFocusTest {
    private static let panelController = PanelController()

    static func run() {
        NSLog("SPIKE: iniciando teste de foco")
        // 1. Traz o TextEdit pra frente (vira o app "vítima" cujo foco não pode ser roubado).
        if let textEdit = URL(string: "file:///System/Applications/TextEdit.app") {
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = true
            NSWorkspace.shared.openApplication(at: textEdit, configuration: cfg) { _, _ in }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            logFocus("PRE-SHOW")
            // 2. Mostra o card sem ativar o app.
            panelController.show(
                title: "Permissão pedida pelo Claude Code",
                subtitle: "Bash · echo TESTE  (spike de foco)"
            ) { allow in
                logFocus("POST-CLICK(\(allow ? "Allow" : "Deny"))")
            }
            // 3. Loga foco logo após mostrar (não pode ter mudado) + coords do botão Allow.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                logFocus("POST-SHOW")
                logAllowButtonCoordinates()
                // 4. Dispara um clique de hardware REAL (CGEvent) em cima do botão Allow.
                //    É o teste mais forte: o window server roteia o evento exatamente como um
                //    clique físico, aplicando (ou não) a ativação conforme o estilo do painel.
                if CommandLine.arguments.contains("--spike-click") {
                    synthesizeClickOnAllow()
                }
            }
        }
    }

    private static func logFocus(_ phase: String) {
        let front = NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
        NSLog("SPIKE[\(phase)]: frontmost=\(front) NSApp.isActive=\(NSApp.isActive) keyWindow=\(NSApp.keyWindow != nil)")
    }

    /// Loga o centro do botão Allow em coordenadas globais top-left (pontos) + geometria da
    /// tela, pra um clique externo poder ser mapeado pro espaço de imagem do screenshot.
    private static func logAllowButtonCoordinates() {
        guard let screen = NSScreen.main else { return }
        let H = screen.frame.height
        NSLog("SPIKE-GEO: screenW=\(screen.frame.width) screenH=\(H) backing=\(screen.backingScaleFactor)")

        guard let panel = NSApp.windows.first(where: { $0 is PermissionPanel }) else {
            NSLog("SPIKE-GEO: painel não encontrado"); return
        }
        // O card tem 460pt; o botão Allow ocupa a metade direita da linha de botões (rodapé).
        let f = panel.frame // bottom-left origin, em pontos globais
        let allowCenterBL = NSPoint(x: f.minX + f.width * 0.72, y: f.minY + 38)
        let allowCenterTL = NSPoint(x: allowCenterBL.x, y: H - allowCenterBL.y)
        NSLog("SPIKE-GEO: panelFrame=\(NSStringFromRect(f)) allowCenterTopLeftPts=(\(Int(allowCenterTL.x)),\(Int(allowCenterTL.y)))")
    }

    /// Posta um mouseDown+mouseUp via CGEvent no centro do botão Allow (coords globais
    /// top-left, em pontos). Loga se o processo tem permissão de Acessibilidade — se não
    /// tiver, o window server pode descartar o evento sintético.
    private static func synthesizeClickOnAllow() {
        guard let screen = NSScreen.main,
              let panel = NSApp.windows.first(where: { $0 is PermissionPanel }) else { return }
        let H = screen.frame.height
        let f = panel.frame
        let p = CGPoint(x: f.minX + f.width * 0.72, y: H - (f.minY + 38)) // top-left, pontos

        NSLog("SPIKE-CLICK: AXIsProcessTrusted=\(AXIsProcessTrusted()) postando clique em \(p)")
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: p, mouseButton: .left)
        let up = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: p, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        usleep(60_000)
        up?.post(tap: .cghidEventTap)
    }
}
