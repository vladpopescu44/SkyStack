import Foundation
import Testing
@testable import SkyStack

/// Tests for the pure balance formulas.
@MainActor
struct GameBalanceTests {
    @Test func blockSpeedGrowsWithHeightAndCaps() {
        #expect(GameBalance.blockSpeed(atFloor: 0) == GameBalance.initialBlockSpeed)
        #expect(GameBalance.blockSpeed(atFloor: 10) > GameBalance.blockSpeed(atFloor: 0))
        #expect(GameBalance.blockSpeed(atFloor: 500) == GameBalance.maximumBlockSpeed)
        #expect(GameBalance.blockSpeed(atFloor: -5) == GameBalance.initialBlockSpeed)
    }

    @Test func placementScoreRewardsStreaksAndStorms() {
        #expect(GameBalance.placementScore(perfectStreak: 0, isStorm: false) == 10)
        #expect(GameBalance.placementScore(perfectStreak: 3, isStorm: false) == 55)
        // The streak bonus is capped.
        #expect(GameBalance.placementScore(perfectStreak: 9, isStorm: false) == 85)
        #expect(GameBalance.placementScore(perfectStreak: 0, isStorm: true) == 20)
    }

    @Test func placementStarsCombineBonuses() {
        #expect(GameBalance.placementStars(isPerfect: false, isAnchored: false, isStorm: false, multiplier: 1) == 1)
        #expect(GameBalance.placementStars(isPerfect: true, isAnchored: false, isStorm: false, multiplier: 1) == 2)
        #expect(GameBalance.placementStars(isPerfect: false, isAnchored: true, isStorm: false, multiplier: 1) == 4)
        #expect(GameBalance.placementStars(isPerfect: true, isAnchored: false, isStorm: true, multiplier: 1) == 4)
        #expect(GameBalance.placementStars(isPerfect: true, isAnchored: false, isStorm: false, multiplier: 1.3) == 3)
        #expect(GameBalance.placementStars(isPerfect: false, isAnchored: false, isStorm: false, multiplier: 0.1) == 1)
    }

    @Test func stormBandsRepeatOnSchedule() {
        for floor in 1..<StormBand.firstFloor {
            #expect(StormBand.isStorm(atFloor: floor) == false)
        }
        for floor in 10...14 {
            #expect(StormBand.isStorm(atFloor: floor))
        }
        for floor in 15...21 {
            #expect(StormBand.isStorm(atFloor: floor) == false)
        }
        #expect(StormBand.isStorm(atFloor: 22))
        #expect(StormBand.isStorm(atFloor: 26))
        #expect(StormBand.isStorm(atFloor: 27) == false)

        #expect(StormBand.floorsUntilStorm(from: 1) == 9)
        #expect(StormBand.floorsUntilStorm(from: 12) == nil)
        #expect(StormBand.floorsUntilStorm(from: 15) == 7)
        #expect(StormBand.floorsUntilStorm(from: 21) == 1)
    }
}

/// Tests for upgrade pricing and the stats they produce.
@MainActor
struct UpgradeTests {
    @Test(arguments: UpgradeKind.allCases)
    func costsRiseAndStopAtMaxLevel(kind: UpgradeKind) {
        var previous = 0
        for level in 1...kind.maxLevel {
            let cost = try! #require(kind.cost(forLevel: level))
            #expect(cost > previous)
            #expect(cost % 5 == 0)
            previous = cost
        }
        #expect(kind.cost(forLevel: 0) == nil)
        #expect(kind.cost(forLevel: kind.maxLevel + 1) == nil)
    }

    @Test func starterLoadoutMatchesDesign() {
        let loadout = BuilderLoadout.starter
        #expect(abs(loadout.foundationFraction - 0.58) < 0.0001)
        #expect(loadout.perfectTolerance == 6)
        #expect(loadout.windbreakFactor == 1)
        #expect(loadout.leanCapacity == 1)
        #expect(loadout.starMultiplier == 1)
    }

    @Test func levelsChangeStats() {
        var loadout = BuilderLoadout.starter
        loadout.setLevel(5, for: .foundation)
        loadout.setLevel(2, for: .precision)
        loadout.setLevel(3, for: .windbreak)
        loadout.setLevel(4, for: .ballast)
        loadout.setLevel(1, for: .charm)

        #expect(abs(loadout.foundationFraction - 0.78) < 0.0001)
        #expect(abs(loadout.perfectTolerance - 9.6) < 0.0001)
        #expect(abs(loadout.windbreakFactor - 0.58) < 0.0001)
        #expect(abs(loadout.leanCapacity - 1.88) < 0.0001)
        #expect(abs(loadout.starMultiplier - 1.3) < 0.0001)
    }

    @Test func setLevelClampsToRange() {
        var loadout = BuilderLoadout.starter
        loadout.setLevel(99, for: .ballast)
        #expect(loadout.ballast == UpgradeKind.ballast.maxLevel)
        loadout.setLevel(-3, for: .ballast)
        #expect(loadout.ballast == 0)
    }

    @Test func effectDescriptionsAreHumanReadable() {
        #expect(UpgradeKind.foundation.effectDescription(atLevel: 0) == "Width 58%")
        #expect(UpgradeKind.precision.effectDescription(atLevel: 5) == "Zone ±15 pt")
        #expect(UpgradeKind.windbreak.effectDescription(atLevel: 5) == "Gusts 30%")
        #expect(UpgradeKind.ballast.effectDescription(atLevel: 1) == "Lean limit 1.2")
        #expect(UpgradeKind.charm.effectDescription(atLevel: 1) == "x1.3 stars")
    }

    @Test func builderPalettesCycle() {
        for skin in BuilderSkin.allCases {
            #expect(skin.blockPalette.count == 6)
            #expect(skin.blockColor(forFloor: 0) == skin.blockColor(forFloor: 6))
            #expect(skin.blockColor(forFloor: -1) == skin.blockColor(forFloor: 5))
        }
        #expect(BuilderSkin.starter.price == 0)
    }
}
