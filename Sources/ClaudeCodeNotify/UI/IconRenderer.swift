import AppKit
import SwiftUI

/// Dev: renderiza o ícone do app pra um PNG 1024×1024 (squircle com gradiente + sino),
/// com margem transparente no estilo dos ícones do macOS.
/// Uso: `ClaudeCodeNotify --render-icon /caminho/icon.png`. O .icns é montado por Scripts/make-icon.sh.
@MainActor
enum IconRenderer {
    // Paleta "Claude": coral/clay + creme + escuro.
    static let coral = Color(red: 0.85, green: 0.46, blue: 0.34)   // #D9755E ~ Claude clay
    static let coralDeep = Color(red: 0.78, green: 0.33, blue: 0.18)
    static let cream = Color(red: 0.94, green: 0.93, blue: 0.90)   // #F0EEE6
    static let ink = Color(red: 0.15, green: 0.15, blue: 0.14)

    static func coralGradient() -> LinearGradient {
        LinearGradient(colors: [coral, coralDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Renderiza 4 variações lado a lado pra escolha.
    static func renderVariants(to path: String) {
        let grid = VStack(spacing: 20) {
            HStack(spacing: 20) { labeled(1, variant1()); labeled(2, variant2()) }
            HStack(spacing: 20) { labeled(3, variant3()); labeled(4, variant4()) }
        }
        .padding(28)
        .background(Color(white: 0.16))

        write(view: grid, to: path)
    }

    // 1) Squircle coral + sino branco com badge de notificação (bell.badge.fill)
    static func variant1() -> some View {
        squircle(coralGradient())
            .overlay(Image(systemName: "bell.badge.fill")
                .font(.system(size: 96, weight: .semibold))
                .foregroundStyle(.white))
    }

    // 2) Creme + sparkle coral (faísca do Claude) + ponto de notificação
    static func variant2() -> some View {
        squircle(AnyShapeStyle(cream))
            .overlay(
                Image(systemName: "sparkle")
                    .font(.system(size: 120, weight: .semibold))
                    .foregroundStyle(coralGradient())
            )
            .overlay(alignment: .topTrailing) {
                Circle().fill(.red)
                    .frame(width: 46, height: 46)
                    .overlay(Circle().strokeBorder(cream, lineWidth: 8))
                    .padding(40)
            }
    }

    // 3) Squircle coral + sino branco com a "ding" sendo um sparkle (Claude notification)
    static func variant3() -> some View {
        squircle(coralGradient())
            .overlay(
                Image(systemName: "bell.fill")
                    .font(.system(size: 92, weight: .semibold))
                    .foregroundStyle(.white)
                    .offset(x: -6, y: 4)
            )
            .overlay(alignment: .topTrailing) {
                Image(systemName: "sparkle")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.trailing, 34).padding(.top, 30)
            }
    }

    // 4) Creme + sino coral + sparkle coral na ponta (versão clara)
    static func variant4() -> some View {
        squircle(AnyShapeStyle(cream))
            .overlay(
                Image(systemName: "bell.fill")
                    .font(.system(size: 92, weight: .semibold))
                    .foregroundStyle(coralGradient())
                    .offset(x: -6, y: 4)
            )
            .overlay(alignment: .topTrailing) {
                Image(systemName: "sparkle")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(coralGradient())
                    .padding(.trailing, 36).padding(.top, 32)
            }
    }

    private static func squircle(_ fill: some ShapeStyle) -> some View {
        RoundedRectangle(cornerRadius: 56, style: .continuous)
            .fill(fill)
            .frame(width: 220, height: 220)
    }

    private static func labeled(_ n: Int, _ view: some View) -> some View {
        VStack(spacing: 8) {
            view
            Text("\(n)").font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
        }
    }

    private static func write(view: some View, to path: String) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let bmp = NSBitmapImageRep(data: tiff),
              let png = bmp.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
        print("rendered \(path)")
    }

    /// Fundo do .dmg (660×400): creme + título coral + seta "arraste pro Applications".
    /// As posições casam com os ícones do create-dmg (app em ~165, Applications em ~495, y~190).
    static func renderDMGBackground(to path: String) {
        let w: CGFloat = 660, h: CGFloat = 400
        let view = ZStack {
            cream
            Text("ClaudeCodeNotify")
                .font(.system(size: 30, weight: .bold)).foregroundStyle(coral)
                .position(x: w/2, y: 54)
            Text("Drag the app onto the Applications folder to install")
                .font(.system(size: 14)).foregroundStyle(.secondary)
                .position(x: w/2, y: 84)
            Image(systemName: "arrow.right")
                .font(.system(size: 56, weight: .semibold)).foregroundStyle(coral)
                .position(x: w/2, y: 196)
        }
        .frame(width: w, height: h)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1 // px = pt: casa com a janela do dmgbuild/create-dmg (660×400)
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let bmp = NSBitmapImageRep(data: tiff),
              let png = bmp.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
        print("dmg background rendered \(path)")
    }

    /// Glifo do motivo (sino + spark), sem fundo — base do ícone de menu bar (template).
    static func menuBarGlyph(pt: CGFloat) -> some View {
        ZStack {
            Image(systemName: "bell.fill")
                .font(.system(size: pt * 0.78, weight: .semibold))
                .offset(x: -pt * 0.05, y: pt * 0.02)
            Image(systemName: "sparkle")
                .font(.system(size: pt * 0.40, weight: .bold))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(width: pt, height: pt)
    }

    /// Imagem template (preto + alpha) pro NSStatusItem — o sistema pinta de branco/preto.
    static func menuBarImage(pt: CGFloat = 18) -> NSImage? {
        let view = menuBarGlyph(pt: pt).foregroundStyle(.black)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let img = renderer.nsImage else { return nil }
        img.isTemplate = true
        return img
    }

    /// Dev: preview do glifo (branco sobre fundo escuro, simulando a menu bar).
    static func renderMenuBarPreview(to path: String) {
        let view = menuBarGlyph(pt: 64).foregroundStyle(.white)
            .padding(24)
            .background(Color(white: 0.16))
        write(view: view, to: path)
    }

    /// Ícone oficial (variante 3): squircle coral + sino branco + sparkle (a "ding" do Claude).
    /// `art` = lado da arte; tudo proporcional pra escalar de 220 (preview) a 1024 (icns).
    static func claudeNotifyIcon(art: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: art * 0.2237, style: .continuous)
            .fill(coralGradient())
            .overlay(
                Image(systemName: "bell.fill")
                    .font(.system(size: art * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
                    .offset(x: -art * 0.027, y: art * 0.018)
            )
            .overlay(alignment: .topTrailing) {
                Image(systemName: "sparkle")
                    .font(.system(size: art * 0.29, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.trailing, art * 0.155)
                    .padding(.top, art * 0.137)
            }
            .frame(width: art, height: art)
    }

    static func render(to path: String, size: CGFloat = 1024) {
        let icon = claudeNotifyIcon(art: size * 0.82)
            .frame(width: size, height: size) // centraliza com margem transparente
        write(view: icon, to: path)
    }
}
