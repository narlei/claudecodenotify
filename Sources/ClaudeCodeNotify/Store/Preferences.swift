import Foundation

/// Preferências do usuário: comportamento quando o host está em foco e ajustes por tipo.
struct Preferences: Codable {
    struct TypePref: Codable {
        var durationSeconds: Double
        var soundName: String?   // nil/"" = sem som
    }

    var permission: TypePref
    var idle: TypePref
    var stop: TypePref
    var showCardWhenHostFocused: Bool
    var playSoundWhenHostFocused: Bool

    static let `default` = Preferences(
        permission: TypePref(durationSeconds: 20, soundName: "Glass"),
        idle:       TypePref(durationSeconds: 20, soundName: "Tink"),
        stop:       TypePref(durationSeconds: 10, soundName: "Hero"),
        showCardWhenHostFocused: false,
        playSoundWhenHostFocused: true
    )

    enum CodingKeys: String, CodingKey {
        case permission, idle, stop, showCardWhenHostFocused, playSoundWhenHostFocused
    }

    init(permission: TypePref, idle: TypePref, stop: TypePref,
         showCardWhenHostFocused: Bool, playSoundWhenHostFocused: Bool) {
        self.permission = permission
        self.idle = idle
        self.stop = stop
        self.showCardWhenHostFocused = showCardWhenHostFocused
        self.playSoundWhenHostFocused = playSoundWhenHostFocused
    }

    // Preferências novas ausentes em arquivos antigos recebem os defaults sem perder
    // duração e som já configurados pelo usuário.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        permission = try c.decode(TypePref.self, forKey: .permission)
        idle = try c.decode(TypePref.self, forKey: .idle)
        stop = try c.decode(TypePref.self, forKey: .stop)
        showCardWhenHostFocused = (try? c.decode(Bool.self, forKey: .showCardWhenHostFocused)) ?? false
        playSoundWhenHostFocused = (try? c.decode(Bool.self, forKey: .playSoundWhenHostFocused)) ?? true
    }

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
