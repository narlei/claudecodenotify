import Foundation
import Network

/// Servidor HTTP local mínimo (espelha o contrato do spike/app_mock.py): escuta só em
/// 127.0.0.1 numa porta efêmera, valida o header X-CCNotify-Token, recebe o JSON do hook
/// no body de `POST /decision` e responde o hookSpecificOutput.
///
/// O handler de decisão é assíncrono: pode segurar a resposta enquanto o card está aberto
/// (a requisição do bridge.sh fica bloqueada esperando, exatamente como o terminal nativo).
final class LocalHTTPServer {
    /// Recebe o payload e um completion; chame o completion (decisão + motivo) pra responder.
    typealias DecisionHandler = (HookPayload, @escaping (Decision, String) -> Void) -> Void

    private let token: String
    private let handler: DecisionHandler
    private let queue = DispatchQueue(label: "com.narlei.ClaudeCodeNotify.http")
    private var listener: NWListener?

    /// Porta efêmera escolhida pelo SO (0 até o listener ficar pronto).
    private(set) var port: UInt16 = 0
    var onReady: ((UInt16) -> Void)?

    init(token: String, handler: @escaping DecisionHandler) {
        self.token = token
        self.handler = handler
    }

    func start() throws {
        let params = NWParameters.tcp
        // Bind só no loopback IPv4 + porta efêmera (.any).
        params.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        params.allowLocalEndpointReuse = true

        let listener = try NWListener(using: params)
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.port = self.listener?.port?.rawValue ?? 0
                NSLog("ClaudeCodeNotify: HTTP server pronto em 127.0.0.1:\(self.port)")
                self.onReady?(self.port)
            case .failed(let err):
                NSLog("ClaudeCodeNotify: HTTP server falhou: \(err)")
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] conn in
            self?.accept(conn)
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Conexão

    private func accept(_ conn: NWConnection) {
        conn.start(queue: queue)
        receive(conn, buffer: Data())
    }

    private func receive(_ conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buf = buffer
            if let data { buf.append(data) }

            if let req = HTTPRequest(buffer: buf) {
                self.process(req, on: conn)
            } else if isComplete || error != nil {
                self.send(conn, status: "400 Bad Request", body: Data("{}".utf8))
            } else {
                self.receive(conn, buffer: buf)
            }
        }
    }

    private func process(_ req: HTTPRequest, on conn: NWConnection) {
        guard req.method == "POST", req.path.hasPrefix("/decision") else {
            send(conn, status: "404 Not Found", body: Data("{}".utf8))
            return
        }
        guard req.headers["x-ccnotify-token"] == token else {
            NSLog("ClaudeCodeNotify: token inválido — 403")
            send(conn, status: "403 Forbidden", body: Data("{}".utf8))
            return
        }
        guard let payload = HookPayload.decode(from: req.body) else {
            // Body ilegível: defer (não trava o Claude Code).
            send(conn, status: "200 OK", body: Decision.defer.responseJSON(reason: "payload ilegível -> defer"))
            return
        }

        handler(payload) { [weak self] decision, reason in
            self?.send(conn, status: "200 OK", body: decision.responseJSON(reason: reason))
        }
    }

    private func send(_ conn: NWConnection, status: String, body: Data) {
        var head = "HTTP/1.1 \(status)\r\n"
        head += "Content-Type: application/json\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Connection: close\r\n\r\n"
        var out = Data(head.utf8)
        out.append(body)
        conn.send(content: out, completion: .contentProcessed { _ in conn.cancel() })
    }
}

/// Parser HTTP/1.1 mínimo. Retorna nil enquanto a requisição não está completa
/// (headers + Content-Length bytes de body).
struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]  // nomes em minúsculas
    let body: Data

    init?(buffer: Data) {
        let sep = Data("\r\n\r\n".utf8)
        guard let r = buffer.range(of: sep) else { return nil }
        let headerData = buffer.subdata(in: buffer.startIndex..<r.lowerBound)
        guard let headerText = String(data: headerData, encoding: .utf8) else { return nil }

        var lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        method = String(parts[0])
        path = String(parts[1])

        lines.removeFirst()
        var hdrs: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[line.startIndex..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            hdrs[name] = value
        }
        headers = hdrs

        let contentLength = Int(hdrs["content-length"] ?? "0") ?? 0
        let bodyStart = r.upperBound
        let available = buffer.distance(from: bodyStart, to: buffer.endIndex)
        guard available >= contentLength else { return nil } // ainda chegando
        body = buffer.subdata(in: bodyStart..<buffer.index(bodyStart, offsetBy: contentLength))
    }
}
