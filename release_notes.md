### What's New in 1.1.2

- **Keychain deny fix** — denying the keychain prompt no longer causes it to re-appear on every menu open. The app remembers the decision and stops asking. Reset anytime in Preferences.
- **No re-prompt after updates** — the OAuth token is now cached in the app's own keychain entry, so updating the app no longer triggers a new keychain permission dialog.
- **Usage bars toggle** — new option in Preferences to disable usage bars entirely (useful if you use a custom Claude API without credentials in the system keychain).
- **Smarter onboarding** — the welcome screen has no close button on first launch (exit only via Get Started). If you skip the hook install or keychain grant, Get Started walks you through each one with a confirmation prompt.

---

**ClaudeCodeNotify** is a macOS menu bar app that pops a floating notification when **Claude Code** needs you — when it asks for permission, goes idle waiting for input, or finishes a task. Press **Enter** and it jumps you straight to the terminal where Claude is running (Ghostty, iTerm, Terminal, Cursor, VS Code…). It's a *notifier, not a gatekeeper* — nothing is blocked.

🌐 **Website:** https://claudecodenotify.narlei.com

### Highlights
- Floating, centered notifications for **permission / idle / finished**
- Press **Enter** (or click) to jump to the exact terminal app running Claude
- Per-type **duration & sound** in Preferences
- Menu bar with connection status, **Open at Login**, first-run onboarding
- **Local & private** (127.0.0.1 + token); free & open source

### Install

> ⚠️ **Update Warning:** If you previously installed ClaudeCodeNotify via Homebrew, please do **not** download the `.dmg` file to update. Open your terminal and run `brew upgrade claudecodenotify` instead!

**Option 1: Homebrew (Recommended)**
```bash
brew install narlei/tap/claudecodenotify
```
*(No need to bypass Gatekeeper, Homebrew handles it for you)*

**Option 2: Manual Download**
1. Download **ClaudeCodeNotify.dmg** below and open it.
2. Drag **ClaudeCodeNotify.app** into **Applications**.
3. First launch (unsigned app): **right-click → Open** — or run
   `xattr -dr com.apple.quarantine /Applications/ClaudeCodeNotify.app`

### Connect
4. Click the bell in the menu bar → **Connect Claude Code**.

Requires **macOS 13+** on **Apple Silicon**.

### Support ☕
If it saves you trips to the terminal, consider buying me a coffee:
- **Ko-fi:** https://ko-fi.com/narlei
- **PayPal:** https://paypal.me/narlei
- **Pix:** `contato@narlei.com`
