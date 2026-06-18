#!/bin/bash
# Monta o ClaudeCodeNotify.app a partir do binário do SwiftPM:
#   - copia o executável para Contents/MacOS/
#   - injeta o Info.plist (LSUIElement)
#   - empacota o bridge.sh.template em Contents/Resources/
#   - faz ad-hoc codesign (app não-assinado)
#
# Builds a Universal binary (x86_64 + arm64) so it runs natively on Intel and Apple Silicon.
#
# Uso: Scripts/build-app.sh [debug|release]   (default: release)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-release}"
APP_NAME="ClaudeCodeNotify"
APP="$ROOT/$APP_NAME.app"
# Universal: same --arch flags must go to both `swift build` and `--show-bin-path`
# so the latter resolves the universal output dir (.build/apple/Products/<config>).
ARCHS=(--arch arm64 --arch x86_64)

echo "==> swift build -c $CONFIG (universal: arm64 + x86_64)"
swift build -c "$CONFIG" --package-path "$ROOT" "${ARCHS[@]}"

BIN="$(swift build -c "$CONFIG" --package-path "$ROOT" "${ARCHS[@]}" --show-bin-path)/$APP_NAME"
if [ ! -x "$BIN" ]; then
  echo "ERRO: binário não encontrado em $BIN" >&2
  exit 1
fi

echo "==> montando $APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> ad-hoc codesign"
codesign --force --deep --sign - "$APP"
codesign --verify --verbose "$APP" || true

echo "==> pronto: $APP"
