#!/bin/bash
# Estágio 1 — devolve uma decisão lida de um arquivo MODE (allow|deny|defer).
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="$(cat "$DIR/MODE" 2>/dev/null || echo defer)"
input="$(cat)"
echo "[$(date -u +%H:%M:%SZ)] MODE=$MODE :: $input" >> "$DIR/decide.log"

case "$MODE" in
  allow)
    printf '%s' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"spike: auto-allowed"}}'
    ;;
  deny)
    printf '%s' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"spike: BLOCKED by overlay"}}'
    ;;
  *)
    exit 0  # defer / sem decisão -> fluxo normal
    ;;
esac
