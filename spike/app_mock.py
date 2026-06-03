#!/usr/bin/env python3
# Stand-in do app ClaudeCodeNotify: servidor HTTP local em 127.0.0.1 que valida o token,
# "mostra o card" (delay simulado) e devolve uma decisão. Para o spike, sem Swift.
#
# Decisão lida de ./APP_DECISION (allow|deny). Aceita token via header
# X-CCNotify-Token OU Authorization: Bearer (para testar também o type:http).
import http.server, json, time, sys, pathlib

DIR = pathlib.Path(__file__).resolve().parent
TOKEN = "spike-secret-123"
DELAY = 4          # segundos: finge que o usuário está lendo o card
PORT = 8765
DECISION_FILE = DIR / "APP_DECISION"

class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        auth = self.headers.get("Authorization", "")
        ok = (self.headers.get("X-CCNotify-Token") == TOKEN) or (auth == f"Bearer {TOKEN}")
        if not ok:
            sys.stderr.write(f"[app] REJECTED: bad/missing token (auth={auth!r})\n"); sys.stderr.flush()
            self.send_response(403); self.end_headers(); self.wfile.write(b"{}"); return
        n = int(self.headers.get("Content-Length", 0))
        data = json.loads(self.rfile.read(n) or b"{}")
        ti = data.get("tool_input", {})
        sys.stderr.write(f"[app] QUEUED tool={data.get('tool_name')} cmd={ti.get('command')!r} "
                         f"cwd={data.get('cwd')} session={data.get('session_id','')[:8]} id={data.get('tool_use_id')}\n")
        sys.stderr.write(f"[app] ...mostrando card, esperando {DELAY}s pelo usuário...\n"); sys.stderr.flush()
        time.sleep(DELAY)
        decision = DECISION_FILE.read_text().strip() if DECISION_FILE.exists() else "allow"
        out = json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": decision,
            "permissionDecisionReason": f"spike: user clicked {decision}"
        }}).encode()
        self.send_response(200); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(out))); self.end_headers(); self.wfile.write(out)
        sys.stderr.write(f"[app] RESPONDED {decision}\n"); sys.stderr.flush()

    def log_message(self, *a): pass

if __name__ == "__main__":
    sys.stderr.write(f"[app] listening on 127.0.0.1:{PORT}\n"); sys.stderr.flush()
    http.server.HTTPServer(("127.0.0.1", PORT), H).serve_forever()
