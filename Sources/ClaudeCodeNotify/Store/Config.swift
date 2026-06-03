import Foundation

/// Configuração persistida em config.json: token secreto (gerado uma vez) + flag de seed
/// da allowlist. A porta NÃO fica aqui (é efêmera; vai no portFile a cada launch).
struct Config: Codable {
    var token: String
    var allowlistSeeded: Bool

    /// Carrega do disco; se não existir, gera um token novo e grava.
    static func loadOrCreate() -> Config {
        let url = AppPaths.configFile
        if let data = try? Data(contentsOf: url),
           let cfg = try? JSONDecoder().decode(Config.self, from: data) {
            return cfg
        }
        let cfg = Config(token: Self.generateToken(), allowlistSeeded: false)
        cfg.save()
        return cfg
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        _ = try? AppPaths.ensureSupportDirectory()
        try? data.write(to: AppPaths.configFile, options: .atomic)
        // config tem o token — restringe a 600.
        try? FileManager.default.setAttributes([.posixPermissions: 0o600],
                                               ofItemAtPath: AppPaths.configFile.path)
    }

    /// 32 bytes aleatórios em base64url (sem padding) — seguro e shell-friendly.
    private static func generateToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        for i in bytes.indices { bytes[i] = UInt8.random(in: 0...255) }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
