# Spike — validação da integração com o hook do Claude Code

Prova de conceito de **toda a arquitetura do ClaudeCodeNotify sem uma linha de Swift**.
Valida que o hook `PreToolUse` consegue interceptar o pedido, bloquear o Claude Code, e
receber a decisão de um app externo via HTTP local. Validado no Claude Code **2.1.161**.

> ⚠️ Roda um `claude -p` aninhado (processo separado, consome tokens). Tudo usa um
> `.claude/settings.json` **local desta pasta** — seu `~/.claude/settings.json` global não é tocado.
> Rode os comandos **de dentro de `spike/`**.

```bash
cd spike
chmod +x *.sh
```

## Estágio 0 — captura o input real
Aponte o hook pro `capture.sh` (edite `.claude/settings.json`, troque `bridge.sh` por `capture.sh`):
```bash
claude -p "Use the Bash tool to run exactly: echo hello-from-spike" --allowedTools "Bash"
cat capture.log    # veja o JSON cru: session_id, cwd, tool_input.description, tool_use_id...
```

## Estágio 1 — a decisão controla o CC
Aponte o hook pro `decide.sh`:
```bash
printf 'deny'  > MODE && claude -p "Run with Bash: echo X. Diga se rodou ou foi bloqueado."   # bloqueia
printf 'allow' > MODE && claude -p "Run with Bash: echo X. Diga o stdout."                    # roda sem prompt
```

## Estágio 2 — round-trip bloqueante (o app de verdade, mockado)
Aponte o hook pro `bridge.sh` (config padrão deste repo). Suba o app mock e dispare:
```bash
printf 'allow' > APP_DECISION
python3 app_mock.py 2> app.log &        # servidor em 127.0.0.1:8765
claude -p "Run with Bash: echo E2E. Diga o stdout."   # espera ~4s (o 'card') e roda
cat app.log                              # QUEUED ... waiting 4s ... RESPONDED allow
kill %1                                  # derruba o app -> próxima chamada cai em `defer`
```
Testes diretos (sem claude):
```bash
S='{"tool_name":"Bash","tool_input":{"command":"echo x"},"tool_use_id":"t1"}'
printf '%s' "$S" | ./bridge.sh           # com app up: espera 4s + JSON allow; offline: defer na hora
```

## Estágio 3 — `type:http` (descartado, mas documentado)
Trocar o handler por `{"type":"http","url":"http://127.0.0.1:8765/decision","headers":{"Authorization":"Bearer $MY_TOKEN"},"allowedEnvVars":["MY_TOKEN"]}`
e rodar `MY_TOKEN=spike-secret-123 claude -p ...` funciona **sem script** — porém com o app
**offline a ferramenta roda sozinha** (falha aberta). Por isso o projeto usa `type:command`. Ver `SPEC.md` §1.

## Arquivos
| Arquivo | Papel |
|---|---|
| `.claude/settings.json` | registra o hook PreToolUse (matcher `Bash`) |
| `capture.sh` | Estágio 0 — loga o input, sem decidir |
| `decide.sh` | Estágio 1 — decide via arquivo `MODE` |
| `bridge.sh` | Estágio 2 — ponte bloqueante p/ o app + fallback `defer` offline |
| `app_mock.py` | servidor que faz o papel do app (token + delay + decisão) |

Artefatos de runtime (`*.log`, `MODE`, `APP_DECISION`) são ignorados pelo git.
