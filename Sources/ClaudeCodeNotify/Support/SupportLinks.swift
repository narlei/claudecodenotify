import AppKit

/// Links/ações de doação ("pague um café"). Provedor é só uma URL — fácil de trocar.
/// Ko-fi/PayPal só aparecem no menu quando preenchidos; o Pix sempre (chave copiável).
enum SupportLinks {
    /// Ko-fi. nil = oculto.
    static let koFi: URL? = URL(string: "https://ko-fi.com/narlei")
    /// PayPal.me. nil = oculto.
    static let payPal: URL? = URL(string: "https://paypal.me/narlei")
    /// Chave Pix (copia pro clipboard).
    static let pixKey = "contato@narlei.com"

    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    /// Copia a chave Pix e confirma.
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
