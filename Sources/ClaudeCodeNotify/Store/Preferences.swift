import Foundation

/// Preferências do usuário: por tipo de notificação, quanto tempo fica na tela e qual som toca.
struct Preferences: Codable {
    struct TypePref: Codable {
        var durationSeconds: Double
        var soundName: String?   // nil/"" = sem som
    }

    var permission: TypePref
    var idle: TypePref
    var stop: TypePref

    static let `default` = Preferences(
        permission: TypePref(durationSeconds: 20, soundName: "Glass"),
        idle:       TypePref(durationSeconds: 20, soundName: "Tink"),
        stop:       TypePref(durationSeconds: 10, soundName: "Hero")
    )

    /// Sons do sistema disponíveis (em /System/Library/Sounds). "" = Nenhum.
    static let availableSounds = [
        "", "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"
    ]

    static func load() -> Preferences {
        guard let data = try? Data(contentsOf: AppPaths.preferencesFile),
              let prefs = try? JSONDecoder().decode(Preferences.self, from: data) else {
            return .default
        }
        return prefs
    }

    func save() {
        _ = try? AppPaths.ensureSupportDirectory()
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: AppPaths.preferencesFile, options: .atomic)
    }

    func pref(for kind: NotificationEvent.Kind) -> TypePref {
        switch kind {
        case .permission: return permission
        case .idle:       return idle
        case .stop:       return stop
        case .other:      return permission
        }
    }
}
