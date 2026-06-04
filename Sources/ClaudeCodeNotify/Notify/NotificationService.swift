import AppKit
import SwiftUI

/// Recebe os eventos do servidor e mostra a notificação central. Sem botões: Enter leva ao
/// terminal do Claude; Esc/clique/timeout fecham e devolvem o foco. Um por vez (o novo
/// substitui o anterior).
@MainActor
final class NotificationService {
    private(set) var config: Config
    private var server: LocalHTTPServer?

    private var panel: NotificationPanel?
    private var previousApp: NSRunningApplication?
    private var currentEvent: NotificationEvent?
    private var currentHostApp: NSRunningApplication?
    private var keyMonitor: Any?
    private var clickMonitor: Any?
    private var dismissTask: Task<Void, Never>?

    var onPortChange: ((UInt16) -> Void)?

    init(config: Config) { self.config = config }

    func start() {
        let server = LocalHTTPServer(token: config.token) { [weak self] body, term, pids in
            guard let payload = NotificationPayload.decode(from: body),
                  let event = NotificationEvent(payload: payload, termProgram: term, hostPIDs: pids) else { return }
            Task { @MainActor in self?.present(event) }
        }
        server.onReady = { port in
            Self.writePortFile(port)
            Task { @MainActor in self.onPortChange?(port) }
        }
        do { try server.start(); self.server = server }
        catch { NSLog("ClaudeCodeNotify: não foi possível iniciar o servidor: \(error)") }
    }

    func stop() { server?.stop(); server = nil }

    // MARK: - Apresentação

    private func present(_ event: NotificationEvent) {
        guard event.shouldNotify else { return }

        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let resolvedHostApp = TerminalActivator.resolveHost(pids: event.hostPIDs,
                                                            termProgram: event.termProgram)
        let hostIsFocused = TerminalActivator.isFocused(resolvedHostApp, frontmostApp: frontmostApp)
        let preferences = Preferences.load()
        let pref = preferences.pref(for: event.kind)
        let shouldShowCard = !hostIsFocused || preferences.showCardWhenHostFocused
        let shouldPlaySound = !hostIsFocused || preferences.playSoundWhenHostFocused

        NSLog("ClaudeCodeNotify: notificação kind=\(event.kind) proj=\(event.projectName) hostFocused=\(hostIsFocused) card=\(shouldShowCard) sound=\(shouldPlaySound)")

        // Som sem card não altera foco nem desmonta uma notificação que já esteja visível.
        guard shouldShowCard else {
            if shouldPlaySound { NotificationSound.play(pref.soundName) }
            return
        }

        teardownPanel(restoreFocus: false)      // limpa anterior sem mexer no foco
        previousApp = frontmostApp
        currentEvent = event

        // O fallback pro app anterior serve só para o "go to terminal", nunca para suprimir.
        let hostApp = resolvedHostApp ?? previousApp
        currentHostApp = hostApp

        let hosting = NSHostingView(rootView: NotificationView(event: event, hostAppName: hostApp?.localizedName))
        hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
        let panel = NotificationPanel(contentView: hosting)
        panel.positionTopCenter()
        self.panel = panel

        // Captura o teclado: ativa o app e torna o painel key (escolha do modo notificador).
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        if shouldPlaySound { NotificationSound.play(pref.soundName) }
        installMonitors()
        scheduleAutoDismiss(after: pref.durationSeconds)
    }

    private func goToTerminal() {
        TerminalActivator.activate(currentHostApp)
        teardownPanel(restoreFocus: false) // o terminal já foi ativado
    }

    // MARK: - Monitores de teclado/clique

    private func installMonitors() {
        removeMonitors()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self, self.panel != nil else { return e }
            switch e.keyCode {
            case 36, 76:           // Return / Enter do teclado numérico
                self.goToTerminal(); return nil
            case 53:               // Esc
                self.teardownPanel(restoreFocus: true); return nil
            default:
                return e
            }
        }
        // Clique fora (ou em qualquer lugar) também leva ao terminal? Não — clique no painel fecha.
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] e in
            guard let self, let panel = self.panel else { return e }
            if e.window == panel { self.goToTerminal(); return nil }
            return e
        }
    }

    private func removeMonitors() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        keyMonitor = nil; clickMonitor = nil
    }

    private func scheduleAutoDismiss(after seconds: TimeInterval) {
        dismissTask?.cancel()
        guard seconds > 0 else { return } // 0 = fica até o usuário fechar
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.teardownPanel(restoreFocus: true) }
        }
    }

    private func teardownPanel(restoreFocus: Bool) {
        dismissTask?.cancel(); dismissTask = nil
        removeMonitors()
        panel?.orderOut(nil)
        panel = nil
        currentEvent = nil
        currentHostApp = nil
        if restoreFocus { previousApp?.activate(options: [.activateIgnoringOtherApps]) }
    }

    // MARK: - Port file

    private static func writePortFile(_ port: UInt16) {
        _ = try? AppPaths.ensureSupportDirectory()
        let url = AppPaths.portFile
        try? "\(port)\n".data(using: .utf8)?.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
