import AppKit
import SwiftUI

/// Abre/reusa a janela de boas-vindas (centralizada).
@MainActor
final class OnboardingWindowController {
    static let shared = OnboardingWindowController()
    private var window: NSWindow?

    func show(token: String, isFirstLaunch: Bool = false) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: OnboardingView(token: token, onClose: { [weak self] in
            self?.window?.close()
            self?.window = nil
            // Pop the menu bar open so the user sees the app is running.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: .ccnotifyPopUpMenu, object: nil)
            }
        }))
        let win = NSWindow(contentViewController: hosting)
        win.title = "Welcome — ClaudeCodeNotify"
        // On first launch hide the close button so the only exit is "Get Started".
        win.styleMask = isFirstLaunch ? [.titled] : [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.setContentSize(hosting.view.fittingSize)
        win.center()
        window = win
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }
}
