import AppKit
import SwiftUI

/// Dev: renderiza o card rico pra um PNG (sem janela/foco), pra inspeção de layout.
/// Uso: `ClaudeCodeNotify --render-card [/caminho/saida.png]`
@MainActor
enum CardRenderer {
    static func render(to path: String) {
        let sample = PermissionRequest(payload: sampleBashPayload())
        let view = PermissionCardView(request: sample, queueCount: 2, onDecision: { _ in })
            .padding(24)
            .background(Color(white: 0.10))

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bmp = NSBitmapImageRep(data: tiff),
              let png = bmp.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("falha ao renderizar card\n".utf8))
            return
        }
        try? png.write(to: URL(fileURLWithPath: path))
        print("card renderizado em \(path)")
    }

    private static func sampleBashPayload() -> HookPayload {
        let json = """
        {"session_id":"abc","cwd":"/Users/narlei/Sources/MeuProjeto","tool_name":"Bash",
         "tool_input":{"command":"rm -rf build && npm run deploy","description":"Limpa build e faz deploy de produção"},
         "tool_use_id":"vis1"}
        """
        return HookPayload.decode(from: Data(json.utf8))!
    }
}
