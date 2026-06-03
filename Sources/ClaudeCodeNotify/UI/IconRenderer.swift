import AppKit
import SwiftUI

/// Dev: renderiza o ícone do app pra um PNG 1024×1024 (squircle com gradiente + sino),
/// com margem transparente no estilo dos ícones do macOS.
/// Uso: `ClaudeCodeNotify --render-icon /caminho/icon.png`. O .icns é montado por Scripts/make-icon.sh.
@MainActor
enum IconRenderer {
    static func render(to path: String, size: CGFloat = 1024) {
        let art: CGFloat = size * 0.82
        let icon = RoundedRectangle(cornerRadius: art * 0.2237, style: .continuous)
            .fill(LinearGradient(
                colors: [Color(red: 0.23, green: 0.48, blue: 1.0), Color(red: 0.45, green: 0.22, blue: 0.92)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                Image(systemName: "bell.fill")
                    .font(.system(size: art * 0.46, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .frame(width: art, height: art)
            .frame(width: size, height: size) // centraliza com margem transparente

        let renderer = ImageRenderer(content: icon)
        renderer.scale = 1
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bmp = NSBitmapImageRep(data: tiff),
              let png = bmp.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("falha ao renderizar ícone\n".utf8))
            return
        }
        try? png.write(to: URL(fileURLWithPath: path))
        print("ícone renderizado em \(path)")
    }
}
