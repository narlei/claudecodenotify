import AppKit

/// Toca um som do sistema pelo nome (ex.: "Glass"). Nome vazio/nil = silêncio.
enum NotificationSound {
    static func play(_ name: String?) {
        guard let name, !name.isEmpty, let sound = NSSound(named: name) else { return }
        sound.stop()
        sound.play()
    }
}
