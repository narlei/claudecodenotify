#!/bin/bash
# Cria um .dmg "arraste pro Applications" a partir do ClaudeCodeNotify.app.
# Preferência: dmgbuild (headless, escreve o layout sem precisar do Finder).
# Fallbacks: create-dmg (precisa automar o Finder) e, por fim, hdiutil simples.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/ClaudeCodeNotify.app"
DIST="$ROOT/dist"
DMG="$DIST/ClaudeCodeNotify.dmg"

[ -d "$APP" ] || { echo "ERRO: $APP não existe. Rode 'make app' antes." >&2; exit 1; }
mkdir -p "$DIST"; rm -f "$DIST"/ClaudeCodeNotify-*.dmg "$DMG"

BG="$DIST/.dmg-bg.png"
"$APP/Contents/MacOS/ClaudeCodeNotify" --render-dmg-bg "$BG" >/dev/null 2>&1 || BG=""

if python3 -c "import dmgbuild" >/dev/null 2>&1; then
  echo "==> dmgbuild (headless)"
  DMG_APP="$APP" DMG_BG="$BG" DMG_OUT="$DMG" python3 - <<'PY'
import os, dmgbuild
app = os.environ["DMG_APP"]; out = os.environ["DMG_OUT"]
bg = os.environ.get("DMG_BG") or None
name = os.path.basename(app)
settings = {
    "files": [app],
    "symlinks": {"Applications": "/Applications"},
    "icon_locations": {name: (165, 196), "Applications": (495, 196)},
    "window_rect": ((200, 120), (660, 400)),
    "icon_size": 120,
}
if bg:
    settings["background"] = bg
dmgbuild.build_dmg(out, "Install ClaudeCodeNotify", settings=settings)
PY

elif command -v create-dmg >/dev/null 2>&1; then
  echo "==> create-dmg (requer automação do Finder)"
  BG_ARGS=(); [ -n "$BG" ] && BG_ARGS=(--background "$BG")
  create-dmg \
    --volname "Install ClaudeCodeNotify" \
    --window-pos 200 120 --window-size 660 400 --icon-size 120 \
    --icon "ClaudeCodeNotify.app" 165 196 --app-drop-link 495 196 \
    --hide-extension "ClaudeCodeNotify.app" --no-internet-enable \
    "${BG_ARGS[@]}" "$DMG" "$APP"

else
  echo "==> sem dmgbuild/create-dmg — DMG simples via hdiutil (sem layout)."
  echo "    Para o layout bonito: rode 'make setup' (instala dmgbuild)."
  STAGE="$(mktemp -d)"
  cp -R "$APP" "$STAGE/"; ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "ClaudeCodeNotify" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
  rm -rf "$STAGE"
fi

rm -f "$BG"
echo "==> pronto: $DMG"
