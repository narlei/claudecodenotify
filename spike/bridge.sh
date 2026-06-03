#!/bin/bash
# Estágio 2 — ponte: encaminha o input pro app, BLOQUEIA esperando o clique, devolve a decisão.
# CRÍTICO: em QUALQUER falha emitimos JSON `defer` explícito. Nunca confiar em exit code —
# exit != 2 deixaria a ferramenta PASSAR (erro não-bloqueante).
TOKEN="${CCNOTIFY_TOKEN:-spike-secret-123}"
URL="${CCNOTIFY_URL:-http://127.0.0.1:8765/decision}"

input="$(cat)"
resp="$(printf '%s' "$input" | curl -s --max-time 600 \
          -H "X-CCNotify-Token: $TOKEN" \
          -H "Content-Type: application/json" \
          --data-binary @- "$URL")"

if [ -z "$resp" ]; then
  # app offline / inalcançável -> comporta-se como se não houvesse hook
  printf '%s' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"defer","permissionDecisionReason":"ClaudeCodeNotify offline -> defer"}}'
else
  printf '%s' "$resp"
fi
