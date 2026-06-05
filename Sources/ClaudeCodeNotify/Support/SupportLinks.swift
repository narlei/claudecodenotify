import AppKit

/// Donation links/actions ("buy me a coffee"). Provider is just a URL — easy to swap.
/// Ko-fi/PayPal appear in menu only when filled; Pix always (key is copyable).
enum SupportLinks {
    /// Ko-fi. nil = hidden.
    static let koFi: URL? = URL(string: "https://ko-fi.com/narlei")
    /// PayPal.me. nil = hidden.
    static let payPal: URL? = URL(string: "https://paypal.me/narlei")
    /// Pix key (copies to clipboard).
    static let pixKey = "contato@narlei.com"

    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    /// Copies the Pix key and confirms.
    static func copyPixKey() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pixKey, forType: .string)
        let alert = NSAlert()
        alert.messageText = "Pix key copied"
        alert.informativeText = "\(pixKey)\n\nThanks for supporting ClaudeCodeNotify ☕"
        alert.alertStyle = .informational
        alert.runModal()
    }
}
