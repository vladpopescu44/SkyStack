import Foundation
import SwiftData

/// The single persistent player profile: currency, upgrades, builders and lifetime stats.
@Model
final class PlayerProfile {
    var stars: Int
    var bestScore: Int
    var bestHeight: Int
    var totalRuns: Int
    var totalStarsCollected: Int
    var totalFloors: Int
    var totalPerfects: Int
    var totalAnchors: Int = 0
    var totalLanterns: Int = 0

    var foundationLevel: Int
    var precisionLevel: Int
    var windbreakLevel: Int
    var ballastLevel: Int
    var charmLevel: Int

    var unlockedBuilderIDs: [String]
    var selectedBuilderID: String
    var createdAt: Date

    init(
        stars: Int = 0,
        bestScore: Int = 0,
        bestHeight: Int = 0,
        totalRuns: Int = 0,
        totalStarsCollected: Int = 0,
        totalFloors: Int = 0,
        totalPerfects: Int = 0,
        foundationLevel: Int = 0,
        precisionLevel: Int = 0,
        windbreakLevel: Int = 0,
        ballastLevel: Int = 0,
        charmLevel: Int = 0,
        unlockedBuilderIDs: [String] = [BuilderSkin.starter.rawValue],
        selectedBuilderID: String = BuilderSkin.starter.rawValue,
        createdAt: Date = .now
    ) {
        self.stars = stars
        self.bestScore = bestScore
        self.bestHeight = bestHeight
        self.totalRuns = totalRuns
        self.totalStarsCollected = totalStarsCollected
        self.totalFloors = totalFloors
        self.totalPerfects = totalPerfects
        self.foundationLevel = foundationLevel
        self.precisionLevel = precisionLevel
        self.windbreakLevel = windbreakLevel
        self.ballastLevel = ballastLevel
        self.charmLevel = charmLevel
        self.unlockedBuilderIDs = unlockedBuilderIDs
        self.selectedBuilderID = selectedBuilderID
        self.createdAt = createdAt
    }

    // MARK: - Derived values

    var selectedBuilder: BuilderSkin {
        BuilderSkin(rawValue: selectedBuilderID) ?? .starter
    }

    func isUnlocked(_ skin: BuilderSkin) -> Bool {
        skin.price == 0 || unlockedBuilderIDs.contains(skin.rawValue)
    }

    func level(for kind: UpgradeKind) -> Int {
        switch kind {
        case .foundation: foundationLevel
        case .precision: precisionLevel
        case .windbreak: windbreakLevel
        case .ballast: ballastLevel
        case .charm: charmLevel
        }
    }

    func setLevel(_ level: Int, for kind: UpgradeKind) {
        switch kind {
        case .foundation: foundationLevel = level
        case .precision: precisionLevel = level
        case .windbreak: windbreakLevel = level
        case .ballast: ballastLevel = level
        case .charm: charmLevel = level
        }
    }

    /// The gameplay stats that the current upgrades and builder produce.
    var loadout: BuilderLoadout {
        BuilderLoadout(
            skin: selectedBuilder,
            foundation: foundationLevel,
            precision: precisionLevel,
            windbreak: windbreakLevel,
            ballast: ballastLevel,
            charm: charmLevel
        )
    }

    /// Lightweight value snapshot used for achievement evaluation.
    var statsSnapshot: PlayerStats {
        PlayerStats(
            bestScore: bestScore,
            bestHeight: bestHeight,
            totalRuns: totalRuns,
            totalStarsCollected: totalStarsCollected,
            totalFloors: totalFloors,
            totalPerfects: totalPerfects,
            totalAnchors: totalAnchors,
            totalLanterns: totalLanterns,
            unlockedBuilderCount: BuilderSkin.allCases.filter { isUnlocked($0) }.count,
            maxedUpgradeCount: UpgradeKind.allCases.filter { level(for: $0) >= $0.maxLevel }.count
        )
    }
}
