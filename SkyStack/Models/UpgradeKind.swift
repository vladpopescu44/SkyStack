import Foundation

/// The permanent builder upgrades that can be bought with stars in the workshop.
enum UpgradeKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case foundation
    case precision
    case windbreak
    case ballast
    case charm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .foundation: "Foundation"
        case .precision: "Steady Hands"
        case .windbreak: "Windbreak"
        case .ballast: "Ballast"
        case .charm: "Star Charm"
        }
    }

    var summary: String {
        switch self {
        case .foundation: "A wider base block gives you more room for mistakes."
        case .precision: "Widens the perfect zone so more drops snap into place."
        case .windbreak: "Weakens how far gusts push and slide your blocks."
        case .ballast: "Lets the tower lean further before it topples."
        case .charm: "Every star you earn is worth more."
        }
    }

    var systemImage: String {
        switch self {
        case .foundation: "square.stack.3d.up.fill"
        case .precision: "scope"
        case .windbreak: "wind"
        case .ballast: "scalemass.fill"
        case .charm: "star.fill"
        }
    }

    var maxLevel: Int { 5 }

    var baseCost: Int {
        switch self {
        case .foundation: 80
        case .precision: 60
        case .windbreak: 90
        case .ballast: 110
        case .charm: 100
        }
    }

    /// Star cost to reach `level` (1-based). Returns `nil` when `level` is out of range.
    func cost(forLevel level: Int) -> Int? {
        guard level >= 1, level <= maxLevel else { return nil }
        let raw = Double(baseCost) * pow(1.65, Double(level - 1))
        // Round to a friendly multiple of five.
        return Int((raw / 5).rounded()) * 5
    }

    /// Human readable effect at a given level, e.g. "Width 62%".
    func effectDescription(atLevel level: Int) -> String {
        var loadout = BuilderLoadout.starter
        loadout.setLevel(level, for: self)
        switch self {
        case .foundation:
            return "Width \(Formatters.percent(loadout.foundationFraction))"
        case .precision:
            return "Zone ±\(Int(loadout.perfectTolerance.rounded())) pt"
        case .windbreak:
            return "Gusts \(Formatters.percent(loadout.windbreakFactor))"
        case .ballast:
            return "Lean limit \(String(format: "%.1f", loadout.leanCapacity))"
        case .charm:
            return "\(Formatters.multiplier(loadout.starMultiplier)) stars"
        }
    }
}
