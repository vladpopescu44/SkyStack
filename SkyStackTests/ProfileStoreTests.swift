import Foundation
import SwiftData
import Testing
@testable import SkyStack

/// Persistence tests using an in-memory SwiftData container.
@MainActor
struct ProfileStoreTests {
    private func makeStore(container: ModelContainer? = nil) throws -> (ProfileStore, ModelContainer) {
        let container = try container ?? PersistenceController.makeContainer(inMemory: true)
        return (try ProfileStore(container: container), container)
    }

    private func summary(score: Int, stars: Int = 10, height: Int = 12, perfects: Int = 3, anchors: Int = 0, lanterns: Int = 0) -> RunSummary {
        RunSummary(score: score, starsCollected: stars, height: height, duration: 40, perfectPlacements: perfects,
                   builderID: BuilderSkin.starter.rawValue, anchors: anchors, lanterns: lanterns)
    }

    @Test func freshProfileHasDefaults() throws {
        let (store, _) = try makeStore()
        #expect(store.profile.stars == 0)
        #expect(store.profile.bestScore == 0)
        #expect(store.profile.bestHeight == 0)
        #expect(store.profile.selectedBuilder == .starter)
        #expect(store.profile.isUnlocked(.starter))
        #expect(store.profile.isUnlocked(.zenith) == false)
        #expect(store.recentRuns.isEmpty)
        #expect(store.loadout == .starter)
    }

    @Test func purchaseDeductsStarsAndRaisesLevel() throws {
        let (store, _) = try makeStore()
        try store.grantStars(500)
        let cost = try #require(store.nextCost(of: .precision))

        try store.purchaseUpgrade(.precision)

        #expect(store.level(of: .precision) == 1)
        #expect(store.profile.stars == 500 - cost)
        #expect(store.loadout.precision == 1)
    }

    @Test func purchaseFailsWithoutStars() throws {
        let (store, _) = try makeStore()
        #expect(throws: ProfileError.insufficientStars(needed: UpgradeKind.precision.baseCost)) {
            try store.purchaseUpgrade(.precision)
        }
        #expect(store.level(of: .precision) == 0)
    }

    @Test func purchaseFailsWhenMaxed() throws {
        let (store, _) = try makeStore()
        try store.grantStars(100_000)
        for _ in 0..<UpgradeKind.ballast.maxLevel {
            try store.purchaseUpgrade(.ballast)
        }
        #expect(store.nextCost(of: .ballast) == nil)
        #expect(throws: ProfileError.upgradeMaxed) {
            try store.purchaseUpgrade(.ballast)
        }
    }

    @Test func unlockingBuilderEquipsIt() throws {
        let (store, _) = try makeStore()
        try store.grantStars(BuilderSkin.kite.price)

        try store.unlockBuilder(.kite)

        #expect(store.profile.stars == 0)
        #expect(store.profile.isUnlocked(.kite))
        #expect(store.profile.selectedBuilder == .kite)
        #expect(store.loadout.skin == .kite)
        #expect(throws: ProfileError.builderAlreadyUnlocked) {
            try store.unlockBuilder(.kite)
        }
    }

    @Test func selectingLockedBuilderFails() throws {
        let (store, _) = try makeStore()
        #expect(throws: ProfileError.builderLocked) {
            try store.selectBuilder(.zenith)
        }
        try store.selectBuilder(.starter)
        #expect(store.profile.selectedBuilder == .starter)
    }

    @Test func recordingRunUpdatesStatsAndHistory() throws {
        let (store, _) = try makeStore()

        let outcome = store.recordRun(summary(score: 1200, stars: 40, height: 30, perfects: 9, anchors: 2, lanterns: 1))

        #expect(outcome.isNewBest)
        #expect(outcome.isNewHeightRecord)
        #expect(outcome.previousBest == 0)
        #expect(outcome.totalStars == 40)
        #expect(store.profile.bestScore == 1200)
        #expect(store.profile.bestHeight == 30)
        #expect(store.profile.totalRuns == 1)
        #expect(store.profile.totalStarsCollected == 40)
        #expect(store.profile.totalFloors == 30)
        #expect(store.profile.totalPerfects == 9)
        #expect(store.profile.totalAnchors == 2)
        #expect(store.profile.totalLanterns == 1)
        #expect(store.recentRuns.count == 1)
        #expect(store.recentRuns.first?.score == 1200)

        let worse = store.recordRun(summary(score: 300, stars: 5, height: 8))
        #expect(worse.isNewBest == false)
        #expect(worse.isNewHeightRecord == false)
        #expect(worse.previousBest == 1200)
        #expect(worse.previousBestHeight == 30)
        #expect(store.profile.bestScore == 1200)
        #expect(store.profile.bestHeight == 30)
        #expect(store.profile.totalFloors == 38)
        #expect(store.recentRuns.first?.score == 300)
    }

    @Test func historyIsPruned() throws {
        let (store, _) = try makeStore()
        for index in 0..<(ProfileStore.recentRunLimit + 5) {
            store.recordRun(summary(score: index, stars: 1, height: 1, perfects: 0))
        }
        #expect(store.recentRuns.count == ProfileStore.recentRunLimit)
        #expect(store.profile.totalRuns == ProfileStore.recentRunLimit + 5)
    }

    @Test func dataSurvivesReloadFromSameContainer() throws {
        let (first, container) = try makeStore()
        try first.grantStars(300)
        try first.purchaseUpgrade(.windbreak)
        first.recordRun(summary(score: 777, stars: 9, height: 14))

        let (second, _) = try makeStore(container: container)

        #expect(second.profile.stars == first.profile.stars)
        #expect(second.level(of: .windbreak) == 1)
        #expect(second.profile.bestScore == 777)
        #expect(second.profile.bestHeight == 14)
        #expect(second.recentRuns.count == 1)
    }

    @Test func resetRestoresDefaults() throws {
        let (store, _) = try makeStore()
        try store.grantStars(1000)
        try store.purchaseUpgrade(.charm)
        try store.unlockBuilder(.heron)
        store.recordRun(summary(score: 50, stars: 2, height: 3))

        try store.resetProgress()

        #expect(store.profile.stars == 0)
        #expect(store.level(of: .charm) == 0)
        #expect(store.profile.selectedBuilder == .starter)
        #expect(store.profile.isUnlocked(.heron) == false)
        #expect(store.profile.totalRuns == 0)
        #expect(store.profile.bestHeight == 0)
        #expect(store.recentRuns.isEmpty)
    }

    @Test func achievementsReflectProfile() throws {
        let (store, _) = try makeStore()
        #expect(store.achievements.allSatisfy { !$0.isUnlocked })

        store.recordRun(summary(score: 1500, stars: 10, height: 24, perfects: 5))

        let unlocked = Set(store.achievements.filter(\.isUnlocked).map(\.id))
        #expect(unlocked.contains("firstRun"))
        #expect(unlocked.contains("score1000"))
        #expect(unlocked.contains("height20"))
        #expect(unlocked.contains("height50") == false)
        #expect(unlocked.contains("score5000") == false)
    }
}

/// Tests for achievement evaluation on plain value snapshots.
@MainActor
struct AchievementTests {
    @Test func emptyStatsUnlockNothing() {
        let achievements = AchievementCatalog.evaluate(PlayerStats())
        #expect(achievements.count == 12)
        #expect(achievements.allSatisfy { !$0.isUnlocked })
        // The starter builder is always owned, so "Full Crew" starts at one third.
        #expect(achievements.filter { $0.id != "builders3" }.allSatisfy { $0.progress == 0 })
        let crew = try! #require(achievements.first { $0.id == "builders3" })
        #expect(abs(crew.progress - 1.0 / 3.0) < 0.0001)
    }

    @Test func progressIsClampedAndUnlocksAtTarget() {
        var stats = PlayerStats()
        stats.totalPerfects = 50
        let halfway = try! #require(AchievementCatalog.evaluate(stats).first { $0.id == "perfects100" })
        #expect(halfway.progress == 0.5)
        #expect(halfway.isUnlocked == false)

        stats.totalPerfects = 10_000
        let done = try! #require(AchievementCatalog.evaluate(stats).first { $0.id == "perfects100" })
        #expect(done.progress == 1)
        #expect(done.isUnlocked)
    }

    @Test func mechanicAchievementsTrackAnchorsAndLanterns() {
        var stats = PlayerStats()
        stats.totalAnchors = 10
        stats.totalLanterns = 2
        let achievements = AchievementCatalog.evaluate(stats)
        #expect(achievements.first { $0.id == "anchors10" }?.isUnlocked == true)
        let lantern = try! #require(achievements.first { $0.id == "lanterns5" })
        #expect(lantern.isUnlocked == false)
        #expect(abs(lantern.progress - 0.4) < 0.0001)
    }
}

/// Tests for preference persistence.
@MainActor
struct SettingsStoreTests {
    private func makeDefaults() -> UserDefaults {
        let name = "SkyStackTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func defaultsAreSensible() {
        let settings = SettingsStore(defaults: makeDefaults())
        #expect(settings.hapticsEnabled)
        #expect(settings.controlScheme == .tap)
        #expect(settings.hasSeenHowToPlay == false)
    }

    @Test func valuesPersistAcrossInstances() {
        let defaults = makeDefaults()
        let first = SettingsStore(defaults: defaults)
        first.hapticsEnabled = false
        first.controlScheme = .button
        first.hasSeenHowToPlay = true

        let second = SettingsStore(defaults: defaults)
        #expect(second.hapticsEnabled == false)
        #expect(second.controlScheme == .button)
        #expect(second.hasSeenHowToPlay)
    }
}
