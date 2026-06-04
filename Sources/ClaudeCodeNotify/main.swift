import AppKit

// Bootstrap manual do NSApplication (sem @main / sem storyboard).
// LSUIElement no Info.plist garante "sem Dock"; reforçamos .accessory aqui
// pro caso de rodar via `swift run` sem bundle.
// Operações headless (usadas pelo Makefile / testes) — não sobem a UI.
if CommandLine.arguments.contains("--uninstall") {
    do {
        try HookInstaller.uninstall()
        print("ClaudeCodeNotify: hooks removed from ~/.claude/settings.json (backup created)")
    } catch {
        FileHandle.standardError.write(Data("uninstall error: \(error)\n".utf8))
        exit(1)
    }
    exit(0)
}
if CommandLine.arguments.contains("--write-bridge") {
    do {
        let cfg = Config.loadOrCreate()
        let path = try HookInstaller.writeBridgeOnly(token: cfg.token)
        print(path)  // prints the bridge.sh path (for a local settings.json)
    } catch {
        FileHandle.standardError.write(Data("write-bridge error: \(error)\n".utf8))
        exit(1)
    }
    exit(0)
}
if CommandLine.arguments.contains("--install") {
    do {
        let cfg = Config.loadOrCreate()
        try HookInstaller.install(token: cfg.token)
        print("ClaudeCodeNotify: hooks installed in ~/.claude/settings.json (\(HookInstaller.managedEvents.joined(separator: ", ")))")
    } catch {
        FileHandle.standardError.write(Data("install error: \(error)\n".utf8))
        exit(1)
    }
    exit(0)
}

if let idx = CommandLine.arguments.firstIndex(of: "--render-notif") {
    let out = CommandLine.arguments.indices.contains(idx + 1) ? CommandLine.arguments[idx + 1] : "/tmp/ccn-notif.png"
    MainActor.assumeIsolated { NotificationRenderer.render(to: out) }
    exit(0)
}
if let idx = CommandLine.arguments.firstIndex(of: "--render-icon") {
    let out = CommandLine.arguments.indices.contains(idx + 1) ? CommandLine.arguments[idx + 1] : "/tmp/ccn-icon.png"
    MainActor.assumeIsolated { IconRenderer.render(to: out) }
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // menu bar, sem Dock (reforça o LSUIElement do Info.plist)

let delegate = AppDelegate()
app.delegate = delegate

app.run()
