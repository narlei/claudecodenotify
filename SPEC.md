# ClaudeCodeNotify — Especificação

App de menu bar (macOS, Swift) que intercepta os pedidos de permissão do Claude Code
e os apresenta num card flutuante central, com Allow / Allow+não-perguntar / Deny —
pra não ter que voltar pro terminal. App não-assinado, distribuído via GitHub.

---

## 1. Arquitetura — fluxo de uma permissão

```
Claude Code (terminal)
  │  dispara hook PreToolUse (type: command) para toda ferramenta que casar com o matcher
  ▼
bridge.sh  (processo curto)
  │  POST bloqueante → http://127.0.0.1:<porta>/decision
  │  headers: token secreto  |  body: JSON do hook (cwd, session_id, tool_name, tool_input, tool_use_id...)
  ▼
ClaudeCodeNotify  (app menu bar, sempre rodando)
  │  1. valida o token
  │  2. checa a allowlist própria
  │       ├─ casa (já liberado) → responde "allow" na hora, sem card
  │       └─ ferramenta não gerenciada (Read/Grep/…) → responde "defer" (CC decide do jeito nativo)
  │  3. não casa e é gerenciada → enfileira (chave = tool_use_id) e mostra o card central
  ▼
Usuário clica  (Allow | Allow+não-perguntar | Deny[+motivo])
  │
  ▼
App responde no corpo da requisição → bridge.sh imprime o JSON no stdout → CC aplica a decisão e segue
```

**Por que `bridge.sh` (type:command) e não `type:http` direto?**
O `type:http` existe e funciona (CC POSTa direto numa URL, lê a decisão do corpo 2xx, token via
header `Authorization`). **Mas falha ABERTA:** se o app estiver offline, "connection failure →
non-blocking error → execution continues", ou seja, a ferramenta roda sem gate. Inaceitável pra um
app de gatekeeping. O `bridge.sh` é um **ponto de decisão local que sempre existe**, então *nós*
controlamos o caso offline (emite `defer` → fluxo nativo). Ver validação no Estágio 3.

---

## 2. Decisões de design

| # | Tema | Decisão |
|---|---|---|
| 1 | **Integração** | Hook `PreToolUse` (oficial; bloqueia e decide; nunca toca no TUI) |
| 2 | **IPC** | `type:command` → `bridge.sh` faz POST bloqueante p/ servidor HTTP local. **`type:http` descartado** (falha aberta offline) |
| 3 | **Quem decide** | O **app** é a autoridade. Allowlist própria. Ferramenta não-gerenciada → `defer` (motor do CC auto-libera, sem reimplementar) |
| 4 | **Allowlist** | Store próprio (`~/Library/Application Support/ClaudeCodeNotify/`). Importa `permissions.allow` do `~/.claude/settings.json` **uma vez** como seed; depois independente |
| 5 | **"Não perguntar de novo"** | App **sugere** um padrão editável (prefixo do comando p/ Bash, pasta p/ Edit) e o usuário ajusta o escopo antes de confirmar |
| 6 | **Concorrência** | Fila; um card por vez; identifica sessão por `cwd`/`session_id`; chave de dedup = `tool_use_id`; badge "N na fila" + nome do projeto no topo |
| 7 | **Timeout** | Nenhum — espera pra sempre, igual ao terminal (mitigado pelo badge da fila) |
| 8 | **App offline** | `bridge.sh` sem resposta em ~1–2s → emite **`defer`** explícito (cai no fluxo nativo; nunca confiar em exit code, pois exit≠2 deixa a ferramenta passar) |
| 9 | **Botões** | Espelha os 3 do CC: Allow / Allow+não-perguntar / Deny. Deny com campo de motivo opcional → volta via `permissionDecisionReason` |
| 10 | **Card** | Rico, adaptado por ferramenta. Header: pasta + ícone. Bash: comando (mono) + `tool_input.description`. Edit/Write: caminho + conteúdo (diff colorido = v2) |
| 11 | **Stack** | Swift + SwiftUI/AppKit. `NSPanel` não-ativante (`nonactivatingPanel` + `becomesKeyOnlyIfNeeded`) — não rouba foco |
| 12 | **Visibilidade** | `collectionBehavior`: `canJoinAllSpaces` + `.fullScreenAuxiliary` (aparece sobre fullscreen/qualquer Space) + som opcional |
| 13 | **Entrada (v1)** | Só mouse. Atalho global de teclado (exige permissão de Acessibilidade) fica pro v2 |
| 14 | **Ciclo de vida** | Menu bar (`LSUIElement`, sem Dock) + abrir no login (`SMAppService`). Ícone mostra status/fila |
| 15 | **Segurança** | Servidor escuta só em `127.0.0.1`. App gera token secreto no install, guardado no `bridge.sh`/headers e validado em toda requisição |
| 16 | **Instalação do hook** | App escreve o hook no `~/.claude/settings.json` automaticamente (com **backup** antes; detecta duplicata) |
| 17 | **Distribuição** | Ad-hoc sign (grátis, roda no Apple Silicon) → ZIP no GitHub Releases → README ensina clique-direito → Abrir |
| 18 | **Assinatura** | Sem conta paga Apple: sem Developer ID/notarização → aviso inevitável na 1ª abertura (aceito) |

---

## 3. Contrato real do hook (Claude Code 2.1.161, capturado na validação)

### Input (stdin do hook)
```json
{
  "session_id": "de061029-bf0a-49e7-8220-b47babb12565",
  "transcript_path": "/Users/<user>/.claude/projects/.../<id>.jsonl",
  "cwd": "/private/tmp/ccnotify-spike",
  "permission_mode": "default",
  "effort": { "level": "high" },
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": { "command": "echo hello", "description": "Echo hello" },
  "tool_use_id": "toolu_01SERMzBwod9AC7Fstiu7fL7"
}
```
Campos que o app usa: `session_id` + `cwd` (fila/header), `tool_name` + `tool_input` (card),
`tool_input.description` (texto pronto do card), `tool_use_id` (chave da fila/dedup),
`permission_mode` (ex.: ignorar em `bypassPermissions`). `transcript_path` disponível p/ contexto extra (v2).

### Output (stdout, exit 0)
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "texto opcional mostrado ao usuário/Claude"
  }
}
```
`permissionDecision`: `allow` | `deny` | `ask` | `defer`.
- `allow` → roda sem prompt · `deny` → bloqueia (reason vai pro Claude)
- `ask` → prompta no fluxo nativo · `defer` → comporta-se como se o hook não existisse

### Exit codes (⚠️ pegadinha de segurança)
| Exit | Efeito |
|---|---|
| 0 | CC lê o stdout como JSON. Sem JSON = sem decisão, fluxo normal |
| 2 | Erro bloqueante. stderr vai pro Claude, ferramenta **bloqueada** |
| outro | Erro **não-bloqueante** — a ferramenta **passa** |

→ Por isso o `bridge.sh` **sempre emite JSON `defer` explícito** em falha; nunca depende de exit code.

### Config no settings.json
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "/caminho/bridge.sh" }
        ]
      }
    ]
  }
}
```
Matcher: `"*"`/`""`/omitido = tudo · `"Bash"` exato · `"Edit|Write"` lista · regex se tiver outros chars.

---

## 4. Resultados da validação (spike, sem Swift)

| Estágio | O que provou | Resultado |
|---|---|---|
| 0 — Captura | Formato real do input | ✅ todos os campos + bônus `description`/`tool_use_id`/`transcript_path` |
| 1 — Decisão | `deny` bloqueia c/ motivo; `allow` roda sem prompt | ✅ app-como-autoridade |
| 2a — Round-trip | Hook → app localhost → bloqueia 4s → responde → CC honra | ✅ |
| 2b — Token | Header errado → 403 | ✅ |
| 2c — Offline | App caído → `bridge.sh` emite `defer`, nada trava | ✅ |
| 2d — E2E real | CC real ponta a ponta pelo app mock | ✅ |
| 3 — `type:http` | Funciona sem script, token via header... | ⚠️ **falha aberta offline → descartado** |

Reprodução em [`spike/README.md`](spike/README.md).

---

## 5. Escopo

**v1:** menu bar + servidor c/ token + instalador do hook + card rico + allow/deny/não-perguntar +
fila multi-sessão + store próprio + **mouse-only**.

**v2:** atalho global de teclado (Acessibilidade) · histórico de decisões · diff colorido no Edit/Write ·
contexto extra via `transcript_path`.

---

## 6. Riscos / pontas abertas

1. **`NSPanel` não-ativante recebendo clique sem ativar o app** — primeiro spike de UI a derriscar
   (`nonactivatingPanel` + `becomesKeyOnlyIfNeeded`).
2. **Latência do caso auto-allow** — o `bridge.sh` bate no app mesmo p/ regras já liberadas; resposta
   tem que ser ~instantânea pra não atrasar cada tool. Medir.
3. **Edição concorrente do `~/.claude/settings.json`** — instalar o hook com backup + merge cuidadoso
   (o usuário pode ter outros hooks).
4. **`bridge.sh` precisa do token** sem vazar — gravar com permissão restrita (chmod 600) no install.
