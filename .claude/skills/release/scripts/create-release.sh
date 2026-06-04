#!/usr/bin/env bash
#
# Cut and publish a GitHub release for ClaudeCodeNotify.
#
#   - version  : CFBundleShortVersionString from Resources/Info.plist
#   - tag      : v<version> (annotated, pushed to origin)
#   - build    : make release  -> dist/ClaudeCodeNotify.dmg + dist/ClaudeCodeNotify-<version>.zip
#   - release  : gh release create, body from release_notes.md, both assets attached
#
# Usage:
#   create-release.sh [--dry-run]
#
set -euo pipefail

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

# Always operate from the repo root.
cd "$(git rev-parse --show-toplevel)"

die() { echo "error: $*" >&2; exit 1; }
note() { echo "==> $*"; }

# --- gather facts -----------------------------------------------------------
command -v gh >/dev/null 2>&1 || die "GitHub CLI (gh) not found. Install it: brew install gh"
[ -f Resources/Info.plist ] || die "Resources/Info.plist not found."
[ -f release_notes.md ]      || die "release_notes.md not found at repo root."

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist) \
  || die "could not read CFBundleShortVersionString from Resources/Info.plist"
[ -n "$VERSION" ] || die "version is empty in Info.plist"

TAG="v${VERSION}"
DMG="dist/ClaudeCodeNotify.dmg"
ZIP="dist/ClaudeCodeNotify-${VERSION}.zip"
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# --- guards -----------------------------------------------------------------
if git rev-parse "$TAG" >/dev/null 2>&1; then
  die "tag $TAG already exists locally — bump CFBundleShortVersionString in Resources/Info.plist first."
fi
if git ls-remote --tags origin "refs/tags/$TAG" | grep -q "$TAG"; then
  die "tag $TAG already exists on origin — bump the version first."
fi
if gh release view "$TAG" >/dev/null 2>&1; then
  die "a GitHub release for $TAG already exists."
fi

# Non-blocking warnings the operator should see.
if [ -n "$(git status --porcelain)" ]; then
  echo "warning: working tree has uncommitted changes — they will NOT be part of the release." >&2
fi
if [ "$BRANCH" != "main" ]; then
  echo "warning: releasing from branch '$BRANCH' (not 'main'). The tag will point at HEAD of this branch." >&2
fi

# --- plan / dry-run ---------------------------------------------------------
cat <<PLAN

  Release plan
  ------------
  version : $VERSION
  tag     : $TAG          (annotated, pushed to origin)
  title   : ClaudeCodeNotify $VERSION
  branch  : $BRANCH @ $(git rev-parse --short HEAD)
  assets  : $DMG
            $ZIP
  notes   : release_notes.md ($(wc -l < release_notes.md | tr -d ' ') lines)

PLAN

if [ "$DRY_RUN" -eq 1 ]; then
  note "dry run — nothing was built, tagged, or published."
  echo "----- release_notes.md (preview) -----"
  head -n 12 release_notes.md
  echo "--------------------------------------"
  exit 0
fi

# --- build ------------------------------------------------------------------
note "building artifacts (make release)"
make release

[ -f "$DMG" ] || die "expected $DMG after 'make release' but it's missing."
[ -f "$ZIP" ] || die "expected $ZIP after 'make release' but it's missing."

# --- tag --------------------------------------------------------------------
note "tagging $TAG"
git tag -a "$TAG" -m "ClaudeCodeNotify $VERSION"
git push origin "$TAG"

# --- release ----------------------------------------------------------------
note "creating GitHub release $TAG"
gh release create "$TAG" \
  --title "ClaudeCodeNotify $VERSION" \
  --notes-file release_notes.md \
  "$DMG" "$ZIP"

note "done. Release published for $TAG."
