import AppKit
import SwiftUI

/// Opens/reuses the GitHub star prompt window (centered). Forces a choice:
/// no close button, exactly like the onboarding first-launch window.
@MainActor
final class StarPromptWindowController {
    static let shared = StarPromptWindowController()
    private var window: NSWindow?

    func show(onStar: @escaping () -> Void, onLater: @escaping () -> Void) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: StarPromptView(
            onStar: { [weak self] in
                self?.window?.close()
                self?.window = nil
                onStar()
            },
            onLater: { [weak self] in
                self?.window?.close()
                self?.window = nil
                onLater()
            }
        ))
        let win = NSWindow(contentViewController: hosting)
        win.title = "ClaudeCodeNotify"
        // No .closable: force a choice between the two buttons.
        win.styleMask = [.titled]
        win.isReleasedWhenClosed = false
        win.setContentSize(hosting.view.fittingSize)
        win.center()
        window = win
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }
}
