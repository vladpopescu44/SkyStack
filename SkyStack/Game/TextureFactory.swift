import SpriteKit
import UIKit

/// Loads the generated art from the asset catalog and builds the two tiny particle textures
/// that are cheaper to make in code. Results are cached per name.
@MainActor
enum TextureFactory {
    private static var cache: [String: SKTexture] = [:]

    /// Centre rect (unit coordinates) for 9-slice block textures: rounded ends stay crisp.
    static let blockCenterRect = CGRect(x: 0.12, y: 0.3, width: 0.76, height: 0.4)

    /// A texture from the asset catalog (see `Artwork/generate_assets.swift`).
    static func art(_ name: String) -> SKTexture {
        cached("art-\(name)") { SKTexture(imageNamed: name) }
    }

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

    /// A thin horizontal streak used by the wind and rain emitters.
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
