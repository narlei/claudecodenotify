import AppKit
import SwiftUI

struct GitHubRelease: Decodable {
    let tagName: String
    let htmlUrl: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
    }
}

@MainActor
final class Updater {
    static let shared = Updater()
    
    private let repoURL = URL(string: "https://api.github.com/repos/narlei/claudecodenotify/releases/latest")!
    
    private(set) var hasNewVersion: Bool = false
    private var lastCheckTime: Date?
    
    private init() {
        Task { await silentCheck() }
    }
    
    func silentCheck() async {
        // Limits silent check to once per hour to avoid GitHub API limits.
        if let last = lastCheckTime, Date().timeIntervalSince(last) < 3600 { return }
        lastCheckTime = Date()
        
        do {
            let (data, response) = try await URLSession.shared.data(from: repoURL)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
            let currentVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "Dev"
            
            if currentVersion == "Dev" || latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
                await MainActor.run { self.hasNewVersion = true }
            }
        } catch {}
    }
    
    func checkForUpdates(explicit: Bool) {
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: repoURL)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    if explicit { self.showError("Failed to fetch update information.") }
                    return
                }
                
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
                
                let currentVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "Dev"
                
                if currentVersion == "Dev" {
                    // When running via `make run` (swift run), there's no .app bundle or Info.plist.
                    if explicit {
                        self.showUpdateAvailable(latestVersion: latestVersion, currentVersion: "Dev", url: release.htmlUrl)
                    }
                    return
                }
                
                if latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
                    self.hasNewVersion = true
                    self.showUpdateAvailable(latestVersion: latestVersion, currentVersion: currentVersion, url: release.htmlUrl)
                } else {
                    self.hasNewVersion = false
                    if explicit { self.showUpToDate(currentVersion: currentVersion) }
                }
            } catch {
                if explicit { self.showError("Network error: \(error.localizedDescription)") }
            }
        }
    }
    
    private func getAppIcon() -> NSImage? {
        if let icon = NSImage(named: "AppIcon") { return icon }
        let renderer = ImageRenderer(content: IconRenderer.claudeNotifyIcon(art: 64))
        renderer.scale = 2
        return renderer.nsImage
    }
    
    private func showUpdateAvailable(latestVersion: String, currentVersion: String, url: URL) {
        let alert = NSAlert()
        alert.icon = getAppIcon()
        alert.messageText = "A new version of ClaudeCodeNotify is available!"
        alert.informativeText = "Version \(latestVersion) is available (you are running \(currentVersion)). Would you like to download it?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Cancel")
        
        // Activate the app to ensure the alert is visible
        NSApp.activate(ignoringOtherApps: true)
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func showUpToDate(currentVersion: String) {
        let alert = NSAlert()
        alert.icon = getAppIcon()
        alert.messageText = "You're up to date!"
        alert.informativeText = "ClaudeCodeNotify \(currentVersion) is currently the newest version available."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.icon = getAppIcon()
        alert.messageText = "Update Check Failed"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
