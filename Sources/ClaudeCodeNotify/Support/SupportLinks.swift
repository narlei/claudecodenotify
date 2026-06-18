import AppKit

/// Support action: opens the website's support section, which hosts all the
/// donation options (Ko-fi, PayPal, Pix). Keeping them on the site means one
/// place to update — the menu just links out.
enum SupportLinks {
    /// Website support section.
    static let supportPage = URL(string: "https://claudecodenotify.narlei.com/#support")!

    /// GitHub repository page (for the star prompt and menu item).
    static let repoPage = URL(string: "https://github.com/narlei/claudecodenotify")!

    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
