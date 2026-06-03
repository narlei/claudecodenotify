import Foundation

/// Input do hook PreToolUse (contrato real do Claude Code 2.1.161 — ver SPEC §3).
/// Só os campos que o app usa; o resto do JSON é ignorado.
struct HookPayload: Decodable {
    let sessionID: String?
    let cwd: String?
    let permissionMode: String?
    let toolName: String?
    let toolUseID: String?
    let toolInput: ToolInput?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case cwd
        case permissionMode = "permission_mode"
        case toolName = "tool_name"
        case toolUseID = "tool_use_id"
        case toolInput = "tool_input"
    }

    /// tool_input varia por ferramenta. Decodificamos os campos comuns e guardamos o resto
    /// como JSON cru pra exibição no card.
    struct ToolInput: Decodable {
        let command: String?       // Bash
        let description: String?   // Bash (texto pronto do card)
        let filePath: String?      // Edit/Write/MultiEdit/NotebookEdit
        let content: String?       // Write
        let raw: [String: JSONValue]

        enum CodingKeys: String, CodingKey {
            case command, description, content
            case filePath = "file_path"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            command = try c.decodeIfPresent(String.self, forKey: .command)
            description = try c.decodeIfPresent(String.self, forKey: .description)
            content = try c.decodeIfPresent(String.self, forKey: .content)
            filePath = try c.decodeIfPresent(String.self, forKey: .filePath)
            raw = (try? [String: JSONValue](from: decoder)) ?? [:]
        }
    }

    static func decode(from data: Data) -> HookPayload? {
        try? JSONDecoder().decode(HookPayload.self, from: data)
    }
}

/// Valor JSON genérico, pra preservar campos arbitrários de tool_input.
enum JSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else if let o = try? c.decode([String: JSONValue].self) { self = .object(o) }
        else { self = .null }
    }

    var displayString: String {
        switch self {
        case .string(let s): return s
        case .number(let n): return n == n.rounded() ? String(Int(n)) : String(n)
        case .bool(let b): return String(b)
        case .null: return "null"
        case .array(let a): return a.map(\.displayString).joined(separator: ", ")
        case .object(let o): return o.map { "\($0): \($1.displayString)" }.joined(separator: ", ")
        }
    }
}
