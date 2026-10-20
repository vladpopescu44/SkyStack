import Foundation

/// The resolved gameplay stats for a build, derived from the player's upgrade levels.
struct BuilderLoadout: Equatable, Sendable {
    var skin: BuilderSkin
    var foundation: Int
    var precision: Int
    var windbreak: Int
    var ballast: Int
    var charm: Int

    static let starter = BuilderLoadout(skin: .starter, foundation: 0, precision: 0, windbreak: 0, ballast: 0, charm: 0)

    /// Width of the base block as a fraction of the playfield.
    var foundationFraction: Double { 0.58 + 0.04 * Double(foundation) }

    /// Maximum offset in points that still counts as a perfect placement.
    var perfectTolerance: Double { 6 + 1.8 * Double(precision) }

    /// Multiplier applied to wind push and slip. Lower is better.
    var windbreakFactor: Double { 1 - 0.14 * Double(windbreak) }

    /// How much lean the tower tolerates before it topples.
    var leanCapacity: Double { 1 + 0.22 * Double(ballast) }

    /// Multiplier applied to every star reward.
    var starMultiplier: Double { 1 + 0.3 * Double(charm) }

    func level(for kind: UpgradeKind) -> Int {
        switch kind {
        case .foundation: foundation
        case .precision: precision
        case .windbreak: windbreak
        case .ballast: ballast
        case .charm: charm
        }
    }

    mutating func setLevel(_ level: Int, for kind: UpgradeKind) {
        let clamped = min(max(level, 0), kind.maxLevel)
        switch kind {
        case .foundation: foundation = clamped
        case .precision: precision = clamped
        case .windbreak: windbreak = clamped
        case .ballast: ballast = clamped
        case .charm: charm = clamped
        }
    }
}
