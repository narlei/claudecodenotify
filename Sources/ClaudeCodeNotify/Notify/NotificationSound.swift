import AppKit

/// Plays a system sound by name (e.g. "Glass"). Empty/nil name = silent.
enum NotificationSound {
    static func play(_ name: String?) {
        guard let name, !name.isEmpty, let sound = NSSound(named: name) else { return }
        sound.stop()
        sound.play()
    }
}
