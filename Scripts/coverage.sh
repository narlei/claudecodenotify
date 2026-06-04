#!/bin/bash
# Gera o relatório de cobertura (llvm-cov) dos arquivos de lógica testável.
# Requer que `swift test --enable-code-coverage` já tenha rodado.
# Se $GITHUB_STEP_SUMMARY existir (CI), também publica o resumo no PR.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$(swift build --package-path "$ROOT" --show-bin-path)"
PROF="$BIN/codecov/default.profdata"

XCTEST="$BIN/ClaudeCodeNotifyPackageTests.xctest/Contents/MacOS/ClaudeCodeNotifyPackageTests"
[ -x "$XCTEST" ] || XCTEST="$BIN/ClaudeCodeNotifyPackageTests.xctest"

if [ ! -f "$PROF" ]; then
  echo "ERRO: $PROF não existe — rode 'swift test --enable-code-coverage' antes." >&2
  exit 1
fi

# Apenas a lógica que cobrimos (UI/AppKit/serviços de sistema ficam de fora de propósito).
FILES=(
  "$ROOT/Sources/ClaudeCodeNotify/Hook/HookInstaller.swift"
  "$ROOT/Sources/ClaudeCodeNotify/Store/AppPaths.swift"
  "$ROOT/Sources/ClaudeCodeNotify/Store/Config.swift"
  "$ROOT/Sources/ClaudeCodeNotify/Store/Preferences.swift"
  "$ROOT/Sources/ClaudeCodeNotify/Notify/NotificationPayload.swift"
  "$ROOT/Sources/ClaudeCodeNotify/Notify/NotificationEvent.swift"
)

report="$(xcrun llvm-cov report "$XCTEST" -instr-profile "$PROF" \
  -ignore-filename-regex='Tests/|\.build/' "${FILES[@]}")"

echo "$report"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Cobertura (lógica testável)"
    echo '```'
    echo "$report"
    echo '```'
  } >> "$GITHUB_STEP_SUMMARY"
fi
