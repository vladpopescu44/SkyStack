import SwiftUI

/// A platform-independent RGB triple so the same palette can be used
/// by SwiftUI views and SpriteKit nodes.
struct RGB: Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    var color: Color { Color(red: red, green: green, blue: blue) }
    var uiColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: 1) }
}

/// Playable builders. Each has a look and a block palette for the tower.
/// The first one is free; the rest are unlocked with stars.
enum BuilderSkin: String, CaseIterable, Identifiable, Codable, Sendable {
    case sparrow
    case kite
    case heron
    case aurora
    case comet
    case zenith

    var id: String { rawValue }

    static let starter: BuilderSkin = .sparrow

    var title: String {
        switch self {
        case .sparrow: "Sparrow"
        case .kite: "Kite"
        case .heron: "Heron"
        case .aurora: "Aurora"
        case .comet: "Comet"
        case .zenith: "Zenith"
        }
    }

    var lore: String {
        switch self {
        case .sparrow: "Small, quick and never afraid of heights."
        case .kite: "Rides every gust like it was invited."
        case .heron: "Patient hands, perfectly level blocks."
        case .aurora: "Builds by the light of the northern sky."
        case .comet: "Leaves a trail of sparks on every floor."
        case .zenith: "Has already stood where the sky ends."
        }
    }

    /// Star price to unlock. Zero means available from the start.
    var price: Int {
        switch self {
        case .sparrow: 0
        case .kite: 150
        case .heron: 350
        case .aurora: 600
        case .comet: 900
        case .zenith: 1500
        }
    }

    var primary: RGB {
        switch self {
        case .sparrow: RGB(red: 0.98, green: 0.80, blue: 0.40)
        case .kite: RGB(red: 0.98, green: 0.50, blue: 0.40)
        case .heron: RGB(red: 0.62, green: 0.88, blue: 0.90)
        case .aurora: RGB(red: 0.55, green: 0.92, blue: 0.70)
        case .comet: RGB(red: 1.0, green: 0.62, blue: 0.25)
        case .zenith: RGB(red: 0.96, green: 0.94, blue: 0.88)
        }
    }

    var secondary: RGB {
        switch self {
        case .sparrow: RGB(red: 0.45, green: 0.30, blue: 0.18)
        case .kite: RGB(red: 0.55, green: 0.18, blue: 0.22)
        case .heron: RGB(red: 0.18, green: 0.40, blue: 0.52)
        case .aurora: RGB(red: 0.20, green: 0.45, blue: 0.40)
        case .comet: RGB(red: 0.55, green: 0.20, blue: 0.08)
        case .zenith: RGB(red: 0.25, green: 0.28, blue: 0.45)
        }
    }

    var glow: RGB {
        switch self {
        case .sparrow: RGB(red: 0.40, green: 0.80, blue: 1.0)
        case .kite: RGB(red: 1.0, green: 0.85, blue: 0.45)
        case .heron: RGB(red: 0.80, green: 1.0, blue: 0.95)
        case .aurora: RGB(red: 0.75, green: 0.60, blue: 1.0)
        case .comet: RGB(red: 1.0, green: 0.90, blue: 0.50)
        case .zenith: RGB(red: 1.0, green: 0.88, blue: 0.40)
        }
    }

    /// Colours used for the tower blocks, cycled by floor.
    var blockPalette: [RGB] {
        switch self {
        case .sparrow:
            [RGB(red: 0.98, green: 0.42, blue: 0.40), RGB(red: 1.0, green: 0.72, blue: 0.30),
             RGB(red: 0.45, green: 0.82, blue: 0.45), RGB(red: 0.35, green: 0.65, blue: 0.98),
             RGB(red: 0.72, green: 0.50, blue: 0.95), RGB(red: 0.98, green: 0.55, blue: 0.75)]
        case .kite:
            [RGB(red: 1.0, green: 0.45, blue: 0.35), RGB(red: 1.0, green: 0.62, blue: 0.30),
             RGB(red: 1.0, green: 0.80, blue: 0.35), RGB(red: 0.95, green: 0.40, blue: 0.55),
             RGB(red: 0.85, green: 0.35, blue: 0.70), RGB(red: 1.0, green: 0.55, blue: 0.45)]
        case .heron:
            [RGB(red: 0.40, green: 0.80, blue: 0.85), RGB(red: 0.30, green: 0.65, blue: 0.80),
             RGB(red: 0.55, green: 0.90, blue: 0.75), RGB(red: 0.25, green: 0.50, blue: 0.70),
             RGB(red: 0.70, green: 0.92, blue: 0.95), RGB(red: 0.35, green: 0.72, blue: 0.68)]
        case .aurora:
            [RGB(red: 0.40, green: 0.90, blue: 0.65), RGB(red: 0.55, green: 0.50, blue: 0.95),
             RGB(red: 0.30, green: 0.80, blue: 0.85), RGB(red: 0.75, green: 0.45, blue: 0.95),
             RGB(red: 0.45, green: 0.95, blue: 0.80), RGB(red: 0.35, green: 0.60, blue: 0.95)]
        case .comet:
            [RGB(red: 1.0, green: 0.55, blue: 0.20), RGB(red: 0.95, green: 0.30, blue: 0.25),
             RGB(red: 1.0, green: 0.78, blue: 0.30), RGB(red: 0.80, green: 0.25, blue: 0.40),
             RGB(red: 1.0, green: 0.45, blue: 0.30), RGB(red: 0.60, green: 0.20, blue: 0.45)]
        case .zenith:
            [RGB(red: 1.0, green: 0.85, blue: 0.40), RGB(red: 0.95, green: 0.95, blue: 0.98),
             RGB(red: 0.30, green: 0.35, blue: 0.65), RGB(red: 1.0, green: 0.75, blue: 0.30),
             RGB(red: 0.80, green: 0.82, blue: 0.95), RGB(red: 0.45, green: 0.50, blue: 0.85)]
        }
    }

    /// Block colour for a given floor, cycling through the palette.
    func blockColor(forFloor floor: Int) -> RGB {
        let palette = blockPalette
        return palette[((floor % palette.count) + palette.count) % palette.count]
    }
}
