import Foundation
import Network

/// Minimal local HTTP server: listens only on 127.0.0.1 on an ephemeral port, validates
/// X-CCNotify-Token header and receives `POST /notify` (bridge.sh sends hook payload). Responds
/// 200 immediately — does NOT block anything (app is just a notifier).
final class LocalHTTPServer {
    /// payload (hook body) + TERM_PROGRAM + ancestor PIDs chain (from bridge).
    typealias NotifyHandler = (_ body: Data, _ termProgram: String?, _ hostPIDs: [Int32]) -> Void

    private let token: String
    private let handler: NotifyHandler
    private let queue = DispatchQueue(label: "com.narlei.ClaudeCodeNotify.http")
    private var listener: NWListener?

    private(set) var port: UInt16 = 0
    var onReady: ((UInt16) -> Void)?

    init(token: String, handler: @escaping NotifyHandler) {
        self.token = token
        self.handler = handler
    }

    func start() throws {
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        params.allowLocalEndpointReuse = true

        let listener = try NWListener(using: params)
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.port = self.listener?.port?.rawValue ?? 0
                NSLog("ClaudeCodeNotify: HTTP server ready at 127.0.0.1:\(self.port)")
                self.onReady?(self.port)
            case .failed(let err):
                NSLog("ClaudeCodeNotify: HTTP server failed: \(err)")
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] conn in self?.accept(conn) }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

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
                self.send(conn, status: "400 Bad Request")
            } else {
                self.receive(conn, buffer: buf)
            }
        }
    }

    private func process(_ req: HTTPRequest, on conn: NWConnection) {
        guard req.method == "POST", req.path.hasPrefix("/notify") else {
            send(conn, status: "404 Not Found"); return
        }
        guard req.headers["x-ccnotify-token"] == token else {
            send(conn, status: "403 Forbidden"); return
        }
        let term = req.headers["x-ccnotify-term"]
        let pids = (req.headers["x-ccnotify-pids"] ?? "")
            .split(separator: ",")
            .compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
        handler(req.body, term, pids)
        send(conn, status: "200 OK") // fire-and-forget: responds immediately
    }

    private func send(_ conn: NWConnection, status: String) {
        let body = Data("{}".utf8)
        var head = "HTTP/1.1 \(status)\r\n"
        head += "Content-Type: application/json\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Connection: close\r\n\r\n"
        var out = Data(head.utf8); out.append(body)
        conn.send(content: out, completion: .contentProcessed { _ in conn.cancel() })
    }
}

/// Minimal HTTP/1.1 parser. nil while request is incomplete.
struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]  // names in lowercase
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
            hdrs[name] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        headers = hdrs

        let contentLength = Int(hdrs["content-length"] ?? "0") ?? 0
        let bodyStart = r.upperBound
        let available = buffer.distance(from: bodyStart, to: buffer.endIndex)
        guard available >= contentLength else { return nil }
        body = buffer.subdata(in: bodyStart..<buffer.index(bodyStart, offsetBy: contentLength))
    }
}
