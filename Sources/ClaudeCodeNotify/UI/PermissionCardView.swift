import SwiftUI

/// Card rico, adaptado por ferramenta (SPEC §2 #10):
/// header (projeto + ferramenta + ícone), corpo (Bash: comando mono + descrição;
/// Edit/Write: caminho + conteúdo), e os 3 botões do Claude Code.
struct PermissionCardView: View {
    let request: PermissionRequest
    let queueCount: Int
    let onDecision: (CardDecision) -> Void

    @State private var showDenyReason = false
    @State private var denyReason = ""
    @State private var showPatternEditor = false
    @State private var patternText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            body(for: request)
            if showDenyReason {
                TextField("Motivo (opcional) — enviado ao Claude", text: $denyReason)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }
            if showPatternEditor {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Escopo do \"não perguntar\" (editável):")
                        .font(.caption).foregroundStyle(.secondary)
                    TextField("padrão", text: $patternText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                }
            }
            buttons
        }
        .padding(18)
        .frame(width: 480)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: icon(for: request.toolName))
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(request.toolName)
                    .font(.headline)
                Text(request.cwd ?? request.projectName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer()
            if queueCount > 1 {
                Text("\(queueCount) na fila")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }
        }
    }

    // MARK: - Body por ferramenta

    @ViewBuilder
    private func body(for r: PermissionRequest) -> some View {
        if let command = r.command, !command.isEmpty {
            codeBlock(command)
            if let desc = r.toolDescription, !desc.isEmpty {
                Text(desc).font(.subheadline).foregroundStyle(.secondary)
            }
        } else if let path = r.filePath, !path.isEmpty {
            Text(path)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2).truncationMode(.middle)
            if let content = r.content, !content.isEmpty {
                codeBlock(content, lineLimit: 12)
            }
        } else {
            Text("Permissão pedida pelo Claude Code")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func codeBlock(_ text: String, lineLimit: Int = 8) -> some View {
        // Sem ScrollView (some quando renderizado fora de janela e tem sizing frágil com
        // fittingSize). Cresce com o conteúdo até `lineLimit`; trunca o resto (scroll = v2).
        Text(text)
            .font(.system(size: 12, design: .monospaced))
            .textSelection(.enabled)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Botões

    private var buttons: some View {
        HStack(spacing: 8) {
            Button(role: .destructive) {
                if showDenyReason {
                    onDecision(.deny(reason: denyReason))
                } else {
                    showPatternEditor = false
                    showDenyReason = true
                }
            } label: {
                Text(showDenyReason ? "Confirmar Deny" : "Deny").frame(maxWidth: .infinity)
            }
            .keyboardShortcut(.cancelAction)

            Button {
                if showPatternEditor {
                    onDecision(.allowAlways(pattern: patternText))
                } else {
                    showDenyReason = false
                    patternText = suggestedPattern()
                    showPatternEditor = true
                }
            } label: {
                Text(showPatternEditor ? "Confirmar escopo" : "Allow + não perguntar")
                    .frame(maxWidth: .infinity)
            }

            Button {
                onDecision(.allow)
            } label: {
                Text("Allow").frame(maxWidth: .infinity)
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
        .controlSize(.large)
    }

    // MARK: - Helpers

    /// Sugestão de escopo p/ "não perguntar" (editável no passo 6). Bash: prefixo do comando;
    /// arquivo: pasta. É só a sugestão inicial.
    private func suggestedPattern() -> String {
        if let command = request.command, let first = command.split(separator: " ").first {
            return "\(request.toolName)(\(first):*)"
        }
        if let path = request.filePath {
            return "\(request.toolName)(\((path as NSString).deletingLastPathComponent)/*)"
        }
        return request.toolName
    }

    private func icon(for tool: String) -> String {
        switch tool {
        case "Bash": return "terminal"
        case "Edit", "MultiEdit": return "pencil"
        case "Write": return "square.and.pencil"
        case "NotebookEdit": return "book"
        default: return "bell.badge.fill"
        }
    }
}
