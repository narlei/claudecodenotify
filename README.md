<p align="center">
  <img src="docs/icon.png" width="120" alt="ClaudeCodeNotify icon">
</p>

# ClaudeCodeNotify

A macOS **menu bar** app that pops a **floating notification in the center of your screen** when Claude Code needs you — when it **asks for permission**, is **idle waiting for input**, or **finishes a task**. Press **Enter** (or click) and it jumps you straight to the terminal where Claude is running. Built for people who leave Claude Code working and don't want to babysit the terminal.

> **It's a notifier, not a gatekeeper.** It doesn't block tools or decide permissions — you still approve/deny in the terminal. It just makes sure you *notice* and gets you there fast.

<p align="center">
  <img src="docs/notifications.png" width="480" alt="The three notification types: permission, idle, and finished">
</p>

## Contents

- [How it works](#how-it-works)
- [Features](#features)
- [First launch](#first-launch)
- [Installation](#installation)
- [Build (development)](#build-development)
- [Distribution](#distribution)
- [Background](#background)

## How it works

```
Claude Code (terminal)
  │  Notification hook (permission / idle)  +  Stop hook (task finished)
  ▼
bridge.sh ── POST (127.0.0.1 + token, fire-and-forget) ──►  ClaudeCodeNotify (menu bar, always on)
                                                              │ shows a floating notification, on top of everything
  press Enter / click ────────────────────────────────────────┘ → brings the terminal where Claude runs to the front
```

The notification appears centered at the top, over anything (including fullscreen apps), and captures the keyboard so a single **Enter** takes you to Claude. **Esc**, a click, or the per-type timeout dismisses it. Nothing is blocked — Claude keeps showing its native prompt in the terminal; this just gets you there.

## Features

- **Three event types**, each shown with its own icon/color:
  - 🟠 Claude needs permission
  - 🟡 Claude is idle (waiting for input)
  - 🟢 Claude finished the task (shows a short summary)
- **Enter → jump to the terminal** (Ghostty, iTerm, Terminal, VS Code, WezTerm, …), detected via `$TERM_PROGRAM`.
- **Preferences** (menu → Preferences…): per-type **duration** (0 = stays until you dismiss it) and **sound** (system sounds or None, with preview).
- **Open at Login** via `SMAppService`.
- Local & private: the server listens only on `127.0.0.1` and validates a token.

## First launch

On first launch a **welcome screen** explains how it works and lets you **Connect Claude Code**, toggle **Open at Login**, and open **Preferences** right away. Reopen it anytime from the menu (**Welcome…**).

Everything lives in the **menu bar** (the bell icon). The menu shows a **green/red dot** for the connection status, plus Connect/Disconnect, Welcome, Preferences, and Open at Login.

<p align="center">
  <img src="docs/onboarding.png" width="300" alt="Welcome / onboarding window">
  &nbsp;&nbsp;
  <img src="docs/menu.png" width="240" alt="Menu bar menu with connection status dot">
</p>

## Installation

Requires **macOS 13+** on **Apple Silicon**.

1. Download `ClaudeCodeNotify-x.y.z.zip` from the [Releases page](../../releases) and unzip it.
2. Drag `ClaudeCodeNotify.app` into your **Applications** folder.
3. **First launch** — the app is **unsigned** (no paid Apple account), so macOS blocks a double-click once. Do it once:
   - **right-click** the app → **Open** → **Open** in the dialog; or
   - in a terminal: `xattr -dr com.apple.quarantine /Applications/ClaudeCodeNotify.app && open /Applications/ClaudeCodeNotify.app`
4. A **bell icon** appears in the menu bar. Click it → **Connect Claude Code** (installs the hooks in `~/.claude/settings.json`, with an automatic backup).
5. Optional: **Open at Login** to start it with your system.

To stop it: **Disconnect Claude Code** in the menu.

> The app generates a token on first run and writes `bridge.sh` to `~/.ccnotify/`; its store (token, port, preferences) lives in `~/Library/Application Support/ClaudeCodeNotify/`. Everything is local and only listens on `127.0.0.1`.

## Build (development)

Requires the Xcode/Swift toolchain. Everything goes through the `Makefile`:

```bash
make build      # compile (swift build)
make app        # assemble ClaudeCodeNotify.app (Info.plist + icon + ad-hoc sign)
make install    # build and open the app — then use the menu "Connect Claude Code"
make zip        # package into dist/ClaudeCodeNotify-<version>.zip (for GitHub Releases)
make uninstall  # remove the hooks from ~/.claude/settings.json (with backup)
make help       # list all targets
```

`Scripts/make-icon.sh` regenerates `Resources/AppIcon.icns` when the icon changes (it's checked into the repo).

## Distribution

Unsigned app (no paid Apple account): ad-hoc signed, shipped as a ZIP on GitHub Releases. First launch needs right-click → Open (Gatekeeper). Apple Silicon.

## Background

- [`SPEC.md`](SPEC.md) and [`spike/`](spike/) document the original exploration and the end-to-end validation of the Claude Code hook integration (the spike proved the hook → `bridge.sh` → local HTTP round-trip without any Swift). The shipped app evolved from a permission-gating design into the notifier described above.
