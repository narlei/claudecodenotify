import Foundation

/// Localizações no disco usadas pelo app. Tudo vive em
/// ~/Library/Application Support/ClaudeCodeNotify/
enum AppPaths {
    static let bundleIdentifier = "com.narlei.ClaudeCodeNotify"

    /// Home base. Em produção é o home real; `CCNOTIFY_HOME` permite sandbox em testes
    /// (FileManager.homeDirectoryForCurrentUser ignora $HOME, por isso a env própria).
    static var home: URL {
        if let override = ProcessInfo.processInfo.environment["CCNOTIFY_HOME"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    /// ~/Library/Application Support/ClaudeCodeNotify/
    static var supportDirectory: URL {
        home.appendingPathComponent("Library/Application Support/ClaudeCodeNotify", isDirectory: true)
    }

    /// token secreto + flag de seed da allowlist
    static var configFile: URL { supportDirectory.appendingPathComponent("config.json") }

    /// porta efêmera atual; reescrita a cada launch e lida pelo bridge.sh em runtime
    static var portFile: URL { supportDirectory.appendingPathComponent("port") }

    /// allowlist própria
    static var allowlistFile: URL { supportDirectory.appendingPathComponent("allowlist.json") }

    /// Diretório do bridge.sh. SEM espaço no caminho de propósito: o Claude Code executa o
    /// `command` do hook quebrando em espaços, então "Application Support" (com espaço) falha.
    /// O store (config/port/allowlist) fica em Application Support; só o bridge mora aqui.
    static var bridgeDirectory: URL { home.appendingPathComponent(".ccnotify", isDirectory: true) }

    /// bridge.sh instalado (referenciado pelo hook no settings.json) — caminho sem espaços.
    static var bridgeScript: URL { bridgeDirectory.appendingPathComponent("bridge.sh") }

    /// ~/.claude/settings.json (global do usuário)
    static var claudeSettings: URL {
        home.appendingPathComponent(".claude/settings.json")
    }

    /// Garante que o diretório de suporte existe. Retorna a URL.
    @discardableResult
    static func ensureSupportDirectory() throws -> URL {
        let dir = supportDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
