import Foundation

/// Result of a keychain read through /usr/bin/security.
enum KeychainReadResult: Equatable {
    case success(String)
    case denied      // user clicked Deny on the keychain prompt (exit 128)
    case notFound    // item doesn't exist (exit 44)
    case failure     // anything else; treat as transient

    var value: String? {
        if case .success(let blob) = self { return blob }
        return nil
    }
}

/// Abstracts keychain access so ProfileManager and tests don't touch the real keychain.
protocol CredentialStoring {
    /// Raw JSON blob of Claude Code's credentials (claudeAiOauth + mcpOAuth + ...).
    func readClaudeCredentials() -> KeychainReadResult
    /// Overwrites Claude Code's credentials entry in place.
    func writeClaudeCredentials(_ blob: String) throws
    /// Profile snapshot, stored in the app's own keychain entry.
    func readSnapshot(profileID: UUID) -> KeychainReadResult
    func writeSnapshot(profileID: UUID, blob: String) throws
    func deleteSnapshot(profileID: UUID)
}

enum CredentialStoreError: Error {
    case writeFailed(exitCode: Int32)
}

/// Real implementation delegating to `/usr/bin/security`. The keychain ACL attaches
/// "Always Allow" to the requesting binary; since `security` is a stably-signed Apple
/// tool, the grant persists across reboots and app updates — an in-process
/// SecItemCopyMatching from this ad-hoc-signed app would re-prompt every launch.
/// Writes use `add-generic-password -U`, which updates the item in place and
/// preserves its ACL (verified: Claude CLI keeps working, no re-prompt).
struct SecurityToolCredentialStore: CredentialStoring {
    static let claudeService = "Claude Code-credentials"
    private static let securityTool = "/usr/bin/security"
    private static let snapshotServicePrefix = "ClaudeCodeNotify-profile-"

    func readClaudeCredentials() -> KeychainReadResult {
        read(service: Self.claudeService)
    }

    func writeClaudeCredentials(_ blob: String) throws {
        try write(service: Self.claudeService, blob: blob)
    }

    func readSnapshot(profileID: UUID) -> KeychainReadResult {
        read(service: Self.snapshotServicePrefix + profileID.uuidString)
    }

    func writeSnapshot(profileID: UUID, blob: String) throws {
        try write(service: Self.snapshotServicePrefix + profileID.uuidString, blob: blob)
    }

    func deleteSnapshot(profileID: UUID) {
        _ = run(["delete-generic-password",
                 "-s", Self.snapshotServicePrefix + profileID.uuidString,
                 "-a", NSUserName()])
    }

    // MARK: - security tool plumbing

    private func read(service: String) -> KeychainReadResult {
        let (status, output) = run(["find-generic-password", "-s", service, "-a", NSUserName(), "-w"])
        switch status {
        case 0:
            // -w appends a trailing newline that isn't part of the stored blob.
            guard let raw = output, !raw.isEmpty else { return .failure }
            return .success(raw.hasSuffix("\n") ? String(raw.dropLast()) : raw)
        case 128: return .denied
        case 44:  return .notFound
        default:  return .failure
        }
    }

    private func write(service: String, blob: String) throws {
        // -U updates an existing item in place (data only), preserving its ACL.
        let (status, _) = run(["add-generic-password", "-U",
                               "-s", service, "-a", NSUserName(), "-w", blob])
        guard status == 0 else { throw CredentialStoreError.writeFailed(exitCode: status ?? -1) }
    }

    /// Runs /usr/bin/security with the given arguments. Returns (exit status, stdout).
    private func run(_ arguments: [String]) -> (Int32?, String?) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: Self.securityTool)
        p.arguments = arguments
        let outPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = FileHandle.nullDevice

        do {
            try p.run()
        } catch {
            return (nil, nil)
        }

        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(data: data, encoding: .utf8))
    }
}
