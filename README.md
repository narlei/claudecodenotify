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

## Instalação (usuário final)

Requer **macOS 13+** em **Apple Silicon**.

1. Baixe `ClaudeCodeNotify-x.y.z.zip` na [página de Releases](../../releases) e descompacte.
2. Arraste o `ClaudeCodeNotify.app` para a pasta **Aplicativos**.
3. **Primeira abertura** — o app é **não-assinado** (sem conta paga Apple), então o macOS bloqueia o duplo-clique. Faça uma vez:
   - **clique-direito** no app → **Abrir** → **Abrir** no diálogo; ou
   - pelo terminal: `xattr -dr com.apple.quarantine /Applications/ClaudeCodeNotify.app && open /Applications/ClaudeCodeNotify.app`
4. Vai aparecer um **ícone de sino** na barra de menu. Clique nele → **Conectar Claude Code** (instala o hook no `~/.claude/settings.json`, com backup automático).
5. Opcional: **Abrir no login** pra subir junto com o sistema.

Pronto — na próxima vez que o Claude Code pedir pra rodar Bash/Edit/Write, o card aparece no centro da tela. Para desligar: **Desconectar Claude Code** no menu.

> O app gera um token no 1º run e escreve o `bridge.sh` em `~/.ccnotify/`; o store (token, porta, allowlist) fica em `~/Library/Application Support/ClaudeCodeNotify/`. Tudo local, só escuta em `127.0.0.1`.

## Build (desenvolvimento)

Requer Xcode/Swift toolchain. Tudo passa pelo `Makefile`:

```bash
make build      # compila (swift build)
make app        # monta o ClaudeCodeNotify.app (Info.plist + ícone + ad-hoc sign)
make install    # monta e abre o app — depois use o menu "Conectar Claude Code"
make zip        # empacota em dist/ClaudeCodeNotify-<versão>.zip (GitHub Releases)
make uninstall  # remove o hook do ~/.claude/settings.json (com backup)
make help       # lista todos os alvos
```

`Scripts/make-icon.sh` regenera `Resources/AppIcon.icns` quando o ícone muda (versionado no repo).

## Documentos

- [`SPEC.md`](SPEC.md) — todas as decisões de design + resultados da validação.
- [`spike/`](spike/) — prova de conceito da integração com o hook (reproduzível, sem Swift).
