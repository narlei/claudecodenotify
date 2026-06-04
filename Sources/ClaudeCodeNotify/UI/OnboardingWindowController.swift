import AppKit
import SwiftUI

/// Abre/reusa a janela de boas-vindas (centralizada).
@MainActor
final class OnboardingWindowController {
    static let shared = OnboardingWindowController()
    private var window: NSWindow?

    func show(token: String) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: OnboardingView(token: token, onClose: { [weak self] in
            self?.window?.close()
            self?.window = nil
        }))
        let win = NSWindow(contentViewController: hosting)
        win.title = "Welcome — ClaudeCodeNotify"
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.setContentSize(hosting.view.fittingSize)
        win.center()
        window = win
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }
}
