import SpriteKit
import UIKit

/// Generates every texture the game needs at runtime, so the project ships
/// without bitmap assets. Results are cached per key.
@MainActor
enum TextureFactory {
    private static var cache: [String: SKTexture] = [:]

    /// Size of the master block texture; blocks of any width are drawn with 9-slice scaling.
    static let blockTextureSize = CGSize(width: 96, height: 34)
    /// Centre rect (unit coordinates) that stretches while the rounded corners stay crisp.
    static let blockCenterRect = CGRect(x: 12.0 / 96.0, y: 10.0 / 34.0, width: 72.0 / 96.0, height: 14.0 / 34.0)

    /// A white circle fading to transparent, used for glows and particles.
    static func softCircle(diameter: CGFloat = 64) -> SKTexture {
        cached("soft-\(Int(diameter))") {
            render(size: CGSize(width: diameter, height: diameter)) { context, size in
                let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
                guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: size.width / 2, options: [])
            }
        }
    }

    /// A vertical gradient filling `size`, from the first color at the top to the last at the bottom.
    static func verticalGradient(size: CGSize, colors: [UIColor], key: String) -> SKTexture {
        cached("gradient-\(key)-\(Int(size.width))x\(Int(size.height))") {
            render(size: size) { context, size in
                let cgColors = colors.map(\.cgColor) as CFArray
                guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: nil) else { return }
                context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
        }
    }

    /// A glossy rounded block in the given colour. Stretch it horizontally with `blockCenterRect`.
    static func block(color: RGB, key: String) -> SKTexture {
        cached("block-\(key)") {
            render(size: blockTextureSize) { context, size in
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
                let path = CGPath(roundedRect: rect, cornerWidth: 9, cornerHeight: 9, transform: nil)
                let base = color.uiColor
                let light = blend(base, with: .white, amount: 0.28)
                let dark = blend(base, with: .black, amount: 0.30)

                context.saveGState()
                context.addPath(path)
                context.clip()
                let colors = [light.cgColor, base.cgColor, dark.cgColor] as CFArray
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1]) {
                    context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
                }
                // Glossy strip along the top edge.
                context.setFillColor(UIColor.white.withAlphaComponent(0.32).cgColor)
                context.fill(CGRect(x: 0, y: 2, width: size.width, height: 4))
                // Darker side face along the bottom.
                context.setFillColor(UIColor.black.withAlphaComponent(0.18).cgColor)
                context.fill(CGRect(x: 0, y: size.height - 6, width: size.width, height: 6))
                context.restoreGState()

                context.addPath(path)
                context.setStrokeColor(dark.withAlphaComponent(0.9).cgColor)
                context.setLineWidth(2)
                context.strokePath()
            }
        }
    }

    /// A puffy white cloud with soft edges.
    static func cloud() -> SKTexture {
        cached("cloud") {
            render(size: CGSize(width: 200, height: 100)) { context, size in
                let blobs: [(CGFloat, CGFloat, CGFloat)] = [
                    (0.50, 0.55, 0.30), (0.28, 0.62, 0.22), (0.72, 0.60, 0.25), (0.38, 0.42, 0.24), (0.62, 0.42, 0.22), (0.50, 0.70, 0.20)
                ]
                for (x, y, r) in blobs {
                    let radius = size.height * r
                    let rect = CGRect(x: size.width * x - radius, y: size.height * y - radius, width: radius * 2, height: radius * 2)
                    context.setFillColor(UIColor.white.withAlphaComponent(0.92).cgColor)
                    context.fillEllipse(in: rect)
                }
                // Soft shadow along the underside.
                context.setFillColor(UIColor(red: 0.75, green: 0.82, blue: 0.95, alpha: 0.5).cgColor)
                context.fillEllipse(in: CGRect(x: size.width * 0.2, y: size.height * 0.62, width: size.width * 0.6, height: size.height * 0.22))
            }
        }
    }

    /// A thin horizontal streak used by the wind emitter.
    static func streak() -> SKTexture {
        cached("streak") {
            render(size: CGSize(width: 64, height: 6)) { context, size in
                let colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
                guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1]) else { return }
                context.addPath(CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: 3, cornerHeight: 3, transform: nil))
                context.clip()
                context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: 0), options: [])
            }
        }
    }

    // MARK: - Helpers

    private static func blend(_ color: UIColor, with other: UIColor, amount: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        color.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(
            red: r1 + (r2 - r1) * amount,
            green: g1 + (g2 - g1) * amount,
            blue: b1 + (b2 - b1) * amount,
            alpha: 1
        )
    }

    private static func cached(_ key: String, make: () -> SKTexture) -> SKTexture {
        if let texture = cache[key] { return texture }
        let texture = make()
        cache[key] = texture
        return texture
    }

    private static func render(size: CGSize, draw: (CGContext, CGSize) -> Void) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            draw(context.cgContext, size)
        }
        return SKTexture(image: image)
    }
}
