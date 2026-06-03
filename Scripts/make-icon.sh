#!/bin/bash
# Gera Resources/AppIcon.icns a partir do IconRenderer do app.
# Passo de dev, rodado manualmente quando o ícone muda (o .icns fica versionado).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
PNG="$TMP/icon_1024.png"
SET="$TMP/AppIcon.iconset"
OUT="$ROOT/Resources/AppIcon.icns"

echo "==> build (debug) p/ render"
swift build -c debug --package-path "$ROOT" >/dev/null
BIN="$(swift build -c debug --package-path "$ROOT" --show-bin-path)/ClaudeCodeNotify"

echo "==> renderizando PNG 1024"
"$BIN" --render-icon "$PNG" >/dev/null

echo "==> montando iconset"
mkdir -p "$SET"
for s in 16 32 128 256 512; do
  sips -z $s $s         "$PNG" --out "$SET/icon_${s}x${s}.png"      >/dev/null
  sips -z $((s*2)) $((s*2)) "$PNG" --out "$SET/icon_${s}x${s}@2x.png"  >/dev/null
done

echo "==> iconutil -> $OUT"
iconutil -c icns "$SET" -o "$OUT"
rm -rf "$TMP"
echo "==> pronto: $OUT"
