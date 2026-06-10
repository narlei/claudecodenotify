### What's New in 1.2.0

- **👥 Multi-account profiles** — keep your personal and work Claude accounts on the same machine and switch between them instantly:
  - **Global hotkey per profile** (e.g. ⌃⌥⌘P → Personal, ⌃⌥⌘E → Work) or one click in the menu.
  - The active profile's **emoji shows in the menu bar**, and a confirmation card pops with that account's **fresh usage bars** right after the switch.
  - Inactive profiles keep their **last-seen usage** in the menu, so you know if the other account has room before switching.
  - Setup in **Preferences → Accounts**: capture the account you're logged into, run `claude /login` with the other one — it's detected automatically — and capture it too.
  - Logged in manually with `claude /login`? The app follows along; unknown accounts are never touched.
  - Credentials are snapshotted in your **macOS Keychain** (never on disk), switching never logs anyone out, and with a single account nothing changes.

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
