---
name: release
description: >-
  Cut and publish a new GitHub release for the ClaudeCodeNotify macOS app.
  Use this whenever the user wants to release, ship, publish, cut, or tag a new
  version — phrases like "create a release", "ship the release", "publish
  v1.0.x", "tag and release the app", "cut a new version", or "make a release".
  It builds the .dmg/.zip artifacts via `make release`, reads the version from
  Resources/Info.plist, creates the matching git tag, and publishes a GitHub
  release using release_notes.md as the body. Trigger it even if the user
  doesn't say "GitHub" explicitly — this repo releases on GitHub via `gh`.
---

# Release ClaudeCodeNotify

Publish a new GitHub release: build the artifacts, tag the version from
`Resources/Info.plist`, and create the release with `release_notes.md` as the body.

## What a release consists of

- **Version** — `CFBundleShortVersionString` in `Resources/Info.plist` (e.g. `1.0.3`). This is the single source of truth; the git tag and release title are derived from it.
- **Tag** — `v<version>` (e.g. `v1.0.3`), annotated, pushed to `origin`.
- **Artifacts** — produced by `make release`:
  - `dist/ClaudeCodeNotify.dmg` — stable name (the website's "latest" download link depends on it).
  - `dist/ClaudeCodeNotify-<version>.zip` — versioned zip.
- **Notes** — the contents of `release_notes.md` at the repo root become the release body.

## How to run it

The whole flow is bundled in `scripts/create-release.sh`. It is idempotent-safe: it refuses to run if the tag already exists, so you never double-publish a version.

**Always dry-run first** so the user can see exactly what will happen:

```bash
.claude/skills/release/scripts/create-release.sh --dry-run
```

Show the user the planned version, tag, artifacts, and notes preview. Once they confirm, run it for real:

```bash
.claude/skills/release/scripts/create-release.sh
```

## Before you publish — checklist

Releases are public and irreversible-ish (deleting a release/tag is messy), so verify before running for real:

1. **Version is bumped.** If `v<version>` already exists, the version in `Info.plist` was not bumped — point this out and ask the user to bump it (and the Homebrew tap, if relevant) rather than forcing the tag.
2. **The release commit is on the intended branch and pushed.** The tag is created at `HEAD`. If the user is on a feature branch (not `main`), confirm that's intentional — most releases should be cut from the default branch with everything merged and pushed.
3. **`release_notes.md` reflects this version.** Skim it; if it still mentions an old version or stale install steps, fix it (or ask the user) before publishing.
4. **Working tree is clean.** Uncommitted changes won't be in the release. The script warns but doesn't block — surface the warning to the user.

## After publishing

- Confirm the release URL the script prints and that both assets attached.
- Remind the user that if they ship via the Homebrew tap, the cask/formula in `narlei/homebrew-tap` still needs to be bumped to the new version + sha256.

## Doing it manually (if the script can't be used)

```bash
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
make release
git tag -a "v$VERSION" -m "ClaudeCodeNotify $VERSION"
git push origin "v$VERSION"
gh release create "v$VERSION" \
  --title "ClaudeCodeNotify $VERSION" \
  --notes-file release_notes.md \
  "dist/ClaudeCodeNotify.dmg" "dist/ClaudeCodeNotify-$VERSION.zip"
```
