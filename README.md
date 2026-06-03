# ClaudeCodeNotify

App de **menu bar** pra macOS que mostra as permissões pedidas pelo Claude Code num **card central na tela** — você aprova ou nega ali mesmo, sem voltar pro terminal. Pensado pra quem deixa o Claude Code rodando e não quer ficar de babá do terminal.

> **Status:** arquitetura validada (ver [`spike/`](spike/)), app Swift ainda não iniciado.

## Como funciona (resumão)

```
Claude Code (terminal)
  │  hook PreToolUse (type: command)
  ▼
bridge.sh  ── POST bloqueante (127.0.0.1 + token) ──►  ClaudeCodeNotify (menu bar, sempre on)
                                                          │ checa allowlist própria
                                                          │ se não casa → mostra o card central
  ◄──────────── decisão (allow/deny/defer) ──────────────┘ (você clica)
```

O hook bloqueia o Claude Code enquanto o card está aberto — igual ao prompt nativo do terminal, só que numa janela flutuante por cima de tudo. A decisão volta pelo corpo da requisição e o Claude Code segue.

## Documentos

- [`SPEC.md`](SPEC.md) — todas as decisões de design + resultados da validação.
- [`spike/`](spike/) — prova de conceito da integração com o hook (reproduzível, sem Swift).

## Distribuição (planejada)

App **não-assinado** (sem conta paga Apple), distribuído via GitHub Releases (ZIP, ad-hoc sign). Primeira abertura exige clique-direito → Abrir (Gatekeeper). Roda em Apple Silicon.
