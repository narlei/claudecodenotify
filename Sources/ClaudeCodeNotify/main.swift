import AppKit

// Bootstrap manual do NSApplication (sem @main / sem storyboard).
// LSUIElement no Info.plist garante "sem Dock"; reforçamos .accessory aqui
// pro caso de rodar via `swift run` sem bundle.
// Operações headless (usadas pelo Makefile / testes) — não sobem a UI.
if CommandLine.arguments.contains("--uninstall") {
    do {
        try HookInstaller.uninstall()
        print("ClaudeCodeNotify: hook removido do ~/.claude/settings.json (backup criado)")
    } catch {
        FileHandle.standardError.write(Data("erro ao desinstalar: \(error)\n".utf8))
        exit(1)
    }
    exit(0)
}
if CommandLine.arguments.contains("--write-bridge") {
    do {
        let cfg = Config.loadOrCreate()
        let path = try HookInstaller.writeBridgeOnly(token: cfg.token)
        print(path)  // imprime o caminho do bridge.sh (pra usar num settings.json local)
    } catch {
        FileHandle.standardError.write(Data("erro ao escrever bridge: \(error)\n".utf8))
        exit(1)
    }
    exit(0)
}
if CommandLine.arguments.contains("--install") {
    do {
        let cfg = Config.loadOrCreate()
        try HookInstaller.install(token: cfg.token)
        print("ClaudeCodeNotify: hook instalado em ~/.claude/settings.json (matcher: \(ToolPolicy.matcher))")
    } catch {
        FileHandle.standardError.write(Data("erro ao instalar: \(error)\n".utf8))
        exit(1)
    }
    exit(0)
}

if let idx = CommandLine.arguments.firstIndex(of: "--render-card") {
    let out = CommandLine.arguments.indices.contains(idx + 1) ? CommandLine.arguments[idx + 1] : "/tmp/ccn-card.png"
    MainActor.assumeIsolated { CardRenderer.render(to: out) }
    exit(0)
}

let app = NSApplication.shared
// CCN_REGULAR=1 força .regular (app normal no Dock) — usado só pra testes/diagnóstico
// onde ferramentas externas precisam enxergar o app. Em produção fica .accessory.
if ProcessInfo.processInfo.environment["CCN_REGULAR"] == "1" {
    app.setActivationPolicy(.regular)
} else {
    app.setActivationPolicy(.accessory)
}

let delegate = AppDelegate()
app.delegate = delegate

app.run()
