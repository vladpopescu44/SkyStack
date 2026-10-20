import SwiftUI

/// Central design tokens for the night-sky visual language used across the app.
enum Theme {
    enum Colors {
        static let background = Color(red: 0.045, green: 0.075, blue: 0.17)
        static let surface = Color(red: 0.10, green: 0.15, blue: 0.28)
        static let surfaceElevated = Color(red: 0.14, green: 0.20, blue: 0.36)
        static let stroke = Color.white.opacity(0.09)
        static let sky = Color(red: 0.36, green: 0.72, blue: 1.0)
        static let skyDeep = Color(red: 0.22, green: 0.46, blue: 0.96)
        static let violet = Color(red: 0.55, green: 0.42, blue: 0.98)
        static let star = Color(red: 1.0, green: 0.82, blue: 0.36)
        static let coral = Color(red: 0.98, green: 0.47, blue: 0.42)
        static let cloud = Color(red: 0.90, green: 0.94, blue: 1.0)
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.68)
        static let textTertiary = Color.white.opacity(0.44)
        static let success = Color(red: 0.45, green: 0.88, blue: 0.65)
        static let danger = Color(red: 1.0, green: 0.40, blue: 0.44)
    }

    enum Metrics {
        static let cornerRadius: CGFloat = 22
        static let smallCornerRadius: CGFloat = 14
        static let screenPadding: CGFloat = 20
        /// Maximum width of content columns so layouts stay readable on iPad.
        static let maxContentWidth: CGFloat = 720
    }

    static var skyGradient: LinearGradient {
        LinearGradient(
            colors: [Colors.sky, Colors.skyDeep, Colors.violet],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var starGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 1.0, green: 0.92, blue: 0.62), Colors.star],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.16, blue: 0.34),
                Colors.background,
                Color(red: 0.03, green: 0.04, blue: 0.10)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Typography helpers

extension Font {
    /// Rounded display font used for headlines, scores and big numbers.
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
