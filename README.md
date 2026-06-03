# ClaudeCodeNotify

App de **menu bar** pra macOS que mostra as permissões pedidas pelo Claude Code num **card central na tela** — você aprova ou nega ali mesmo, sem voltar pro terminal. Pensado pra quem deixa o Claude Code rodando e não quer ficar de babá do terminal.

> **Status:** v1 funcional. App Swift (menu bar) implementado e validado ponta a ponta com
> `claude -p` real — o card central aparece, o clique decide (Allow/Deny) e o Claude Code honra.

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

## Build e uso

Requer macOS 13+ (Apple Silicon), Xcode/Swift toolchain. Tudo passa pelo `Makefile`:

```bash
make build      # compila (swift build)
make app        # monta o ClaudeCodeNotify.app (Info.plist + ad-hoc sign)
make install    # monta e abre o app — depois use o menu "Conectar Claude Code"
make zip        # empacota em dist/ClaudeCodeNotify.zip (GitHub Releases)
make uninstall  # remove o hook do ~/.claude/settings.json (com backup)
make help       # lista todos os alvos
```

Pela menu bar: **Conectar Claude Code** instala o hook (com backup do `settings.json`),
**Abrir no login** liga o início automático, e **Mostrar card de teste** previsualiza o card.
O app gera um token no 1º run e escreve o `bridge.sh` em `~/.ccnotify/` (caminho sem espaços,
exigido pelo executor de hooks do Claude Code); o store fica em
`~/Library/Application Support/ClaudeCodeNotify/`.

## Documentos

- [`SPEC.md`](SPEC.md) — todas as decisões de design + resultados da validação.
- [`spike/`](spike/) — prova de conceito da integração com o hook (reproduzível, sem Swift).

## Distribuição (planejada)

App **não-assinado** (sem conta paga Apple), distribuído via GitHub Releases (ZIP, ad-hoc sign). Primeira abertura exige clique-direito → Abrir (Gatekeeper). Roda em Apple Silicon.
