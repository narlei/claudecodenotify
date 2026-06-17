import AppKit
import SwiftUI

/// Hosting view that reacts to the first click even when its window isn't key,
/// so the card stays clickable in the non-focus-stealing mode.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    required init(rootView: Content) { super.init(rootView: rootView) }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// Notification panel. Centered at the top, above everything (including fullscreen).
/// Unlike the old design, THIS captures keyboard (becomes key) so Enter works —
/// an intentional choice for notifier mode.
final class NotificationPanel: NSPanel {
    /// When false, the panel never becomes key and clicks don't activate the app.
    private let stealsFocus: Bool

    init(contentView: NSView, stealsFocus: Bool = true) {
        self.stealsFocus = stealsFocus
        // .nonactivatingPanel lets the panel receive clicks without bringing the app forward.
        let style: NSWindow.StyleMask = stealsFocus ? [.borderless] : [.borderless, .nonactivatingPanel]
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 96),
            styleMask: style, // no titlebar/chrome (avoids black line at the top)
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isReleasedWhenClosed = false

        self.contentView = contentView
        setContentSize(contentView.fittingSize)
    }

    override var canBecomeKey: Bool { stealsFocus }
    override var canBecomeMain: Bool { false }

    func positionTopCenter() {
        guard let screen = targetScreen() else { center(); return }
        let visible = screen.visibleFrame
        let x = visible.midX - frame.width / 2
        let y = visible.maxY - frame.height - 24
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func targetScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }
}
