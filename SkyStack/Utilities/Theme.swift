import SwiftUI

/// Design tokens for Sky Stack's bright, papercraft-over-sky look.
/// Text sits on white "paper" panels over painted sky art; chunky block buttons echo the tower.
enum Theme {
    enum Colors {
        static let ink = Color(red: 0.106, green: 0.137, blue: 0.251)
        static let inkSoft = ink.opacity(0.7)
        static let inkFaint = ink.opacity(0.45)
        static let paper = Color.white
        static let paperShade = Color(red: 0.93, green: 0.96, blue: 1.0)
        static let sky = Color(red: 0.24, green: 0.56, blue: 0.97)
        static let coral = Color(red: 0.98, green: 0.42, blue: 0.40)
        static let sun = Color(red: 1.0, green: 0.68, blue: 0.24)
        static let leaf = Color(red: 0.27, green: 0.72, blue: 0.45)
        static let violet = Color(red: 0.55, green: 0.42, blue: 0.98)
        static let blueprint = Color(red: 0.09, green: 0.23, blue: 0.45)
        static let chalk = Color.white
        static let disabled = Color(red: 0.62, green: 0.66, blue: 0.76)
        static let danger = coral
    }

    enum Metrics {
        static let cornerRadius: CGFloat = 26
        static let smallCornerRadius: CGFloat = 16
        static let screenPadding: CGFloat = 18
        /// Maximum width of content columns so layouts stay readable on iPad.
        static let maxContentWidth: CGFloat = 640
        static let dockHeight: CGFloat = 74
    }
}

// MARK: - Typography helpers

extension Font {
    /// Rounded display font used for headlines, numbers and buttons.
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Shared art helpers

extension BuilderSkin {
    /// Asset name of the generated portrait.
    var portraitAsset: String { "builder-\(rawValue)" }

    /// Asset name of the block texture used for a floor.
    func blockAsset(forFloor floor: Int) -> String {
        let count = blockPalette.count
        return "block-\(rawValue)-\(((floor % count) + count) % count)"
    }
}

extension UpgradeKind {
    /// Asset name of the generated workshop illustration.
    var illustration: String { "upgrade-\(rawValue)" }
}
