#!/bin/bash
# Estágio 0 — captura o JSON cru do PreToolUse, SEM decidir (exit 0, sem stdout).
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
{
  echo "===== HOOK FIRED $(date -u +%Y-%m-%dT%H:%M:%SZ) ====="
  cat            # stdin cru = o JSON de input do hook
  echo
} >> "$DIR/capture.log"
exit 0
