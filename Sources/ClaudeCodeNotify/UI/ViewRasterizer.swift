import AppKit
import SwiftUI

/// Renders a SwiftUI view to an NSImage, with a macOS 12 fallback.
///
/// `ImageRenderer` is macOS 13+, so on macOS 12 (Monterey) we rasterize the *same*
/// SwiftUI view through `NSHostingView` — the icon is pixel-identical across versions.
enum ViewRasterizer {
    /// - Parameter scale: backing scale (2 = retina/@2x). On macOS 12 the bitmap is
    ///   allocated at `points * scale` pixels so the result stays crisp.
    @MainActor
    static func nsImage<V: View>(from view: V, scale: CGFloat = 2) -> NSImage? {
        if #available(macOS 13.0, *) {
            let renderer = ImageRenderer(content: view)
            renderer.scale = scale
            return renderer.nsImage
        }
        return rasterize(view, scale: scale)
    }

    /// macOS 12 fallback: lay out an `NSHostingView` offscreen and cache its display
    /// into a bitmap sized `points * scale`, with `rep.size` left in points so the
    /// drawing context scales points → pixels by `scale` (keeps @2x crispness).
    ///
    /// NOTE: the @2x scaling here relies on `cacheDisplay(in:to:)` honoring the
    /// pixel-vs-point ratio of a manually sized rep. Verify on real macOS 12 hardware.
    @MainActor
    private static func rasterize<V: View>(_ view: V, scale: CGFloat) -> NSImage? {
        let host = NSHostingView(rootView: view)
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        guard size.width > 0, size.height > 0 else { return nil }
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int((size.width * scale).rounded()),
            pixelsHigh: Int((size.height * scale).rounded()),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        rep.size = size

        host.cacheDisplay(in: host.bounds, to: rep)

        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }
}

extension View {
    /// Applies `.formStyle(.grouped)` on macOS 13+. No-op on macOS 12 — the API is
    /// macOS 13+, and the form still renders (without the grouped inset styling).
    @ViewBuilder
    func groupedFormStyleIfAvailable() -> some View {
        if #available(macOS 13.0, *) {
            self.formStyle(.grouped)
        } else {
            self
        }
    }
}
