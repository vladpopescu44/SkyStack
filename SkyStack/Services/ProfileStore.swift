import Foundation
import SwiftData
import Observation

/// Errors surfaced to the interface when a purchase or selection is not possible.
enum ProfileError: LocalizedError, Equatable {
    case insufficientStars(needed: Int)
    case upgradeMaxed
    case builderAlreadyUnlocked
    case builderLocked

    var errorDescription: String? {
        switch self {
        case .insufficientStars(let needed):
            "You need \(Formatters.integer(needed)) more stars."
        case .upgradeMaxed:
            "This upgrade is already at its maximum level."
        case .builderAlreadyUnlocked:
            "This builder is already unlocked."
        case .builderLocked:
            "Unlock this builder before selecting them."
        }
    }
}

/// Owns the player's profile and build history on top of SwiftData.
/// All mutations go through here so views and view models never touch the model context.
@MainActor
@Observable
final class ProfileStore {
    private let context: ModelContext

    private(set) var profile: PlayerProfile
    private(set) var recentRuns: [RunRecord] = []
    /// Set when a save fails so the interface can tell the player.
    private(set) var persistenceErrorMessage: String?

    static let recentRunLimit = 25

    init(container: ModelContainer) throws {
        context = ModelContext(container)
        context.autosaveEnabled = false

        var descriptor = FetchDescriptor<PlayerProfile>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            profile = existing
        } else {
            let created = PlayerProfile()
            context.insert(created)
            profile = created
            try context.save()
        }
        try reloadRuns()
    }

    // MARK: - Derived state

    var loadout: BuilderLoadout { profile.loadout }

    var achievements: [Achievement] {
        AchievementCatalog.evaluate(profile.statsSnapshot)
    }

    func level(of kind: UpgradeKind) -> Int {
        profile.level(for: kind)
    }

    /// Cost of the next level, or `nil` when the upgrade is maxed.
    func nextCost(of kind: UpgradeKind) -> Int? {
        kind.cost(forLevel: profile.level(for: kind) + 1)
    }

    func canAfford(_ amount: Int) -> Bool {
        profile.stars >= amount
    }

    // MARK: - Mutations

    func purchaseUpgrade(_ kind: UpgradeKind) throws {
        guard let cost = nextCost(of: kind) else { throw ProfileError.upgradeMaxed }
        guard canAfford(cost) else {
            throw ProfileError.insufficientStars(needed: cost - profile.stars)
        }
        profile.stars -= cost
        profile.setLevel(profile.level(for: kind) + 1, for: kind)
        try save()
    }

    func unlockBuilder(_ skin: BuilderSkin) throws {
        guard !profile.isUnlocked(skin) else { throw ProfileError.builderAlreadyUnlocked }
        guard canAfford(skin.price) else {
            throw ProfileError.insufficientStars(needed: skin.price - profile.stars)
        }
        profile.stars -= skin.price
        profile.unlockedBuilderIDs.append(skin.rawValue)
        profile.selectedBuilderID = skin.rawValue
        try save()
    }

    func selectBuilder(_ skin: BuilderSkin) throws {
        guard profile.isUnlocked(skin) else { throw ProfileError.builderLocked }
        profile.selectedBuilderID = skin.rawValue
        try save()
    }

    /// Stores a finished build, credits stars and updates lifetime statistics.
    @discardableResult
    func recordRun(_ summary: RunSummary) -> RunOutcome {
        let previousBest = profile.bestScore
        let previousBestHeight = profile.bestHeight
        let isNewBest = summary.score > previousBest
        let isNewHeightRecord = summary.height > previousBestHeight

        profile.stars += summary.starsCollected
        profile.totalRuns += 1
        profile.totalStarsCollected += summary.starsCollected
        profile.totalFloors += summary.height
        profile.totalPerfects += summary.perfectPlacements
        profile.totalAnchors += summary.anchors
        profile.totalLanterns += summary.lanterns
        if isNewBest {
            profile.bestScore = summary.score
        }
        if isNewHeightRecord {
            profile.bestHeight = summary.height
        }

        context.insert(RunRecord(summary: summary))
        persistQuietly()
        pruneOldRuns()

        return RunOutcome(
            summary: summary,
            previousBest: previousBest,
            previousBestHeight: previousBestHeight,
            isNewBest: isNewBest,
            isNewHeightRecord: isNewHeightRecord,
            totalStars: profile.stars
        )
    }

    /// Deletes every build and restores the profile to its initial state.
    func resetProgress() throws {
        try context.delete(model: RunRecord.self)
        context.delete(profile)
        let fresh = PlayerProfile()
        context.insert(fresh)
        profile = fresh
        try save()
    }

    /// Grants stars without a build. Used only to seed deterministic UI-test sessions.
    func grantStars(_ amount: Int) throws {
        profile.stars += amount
        try save()
    }

    // MARK: - Persistence helpers

    private func save() throws {
        try context.save()
        try reloadRuns()
        persistenceErrorMessage = nil
    }

    private func persistQuietly() {
        do {
            try save()
        } catch {
            persistenceErrorMessage = "Progress could not be saved: \(error.localizedDescription)"
        }
    }

    private func reloadRuns() throws {
        var descriptor = FetchDescriptor<RunRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = Self.recentRunLimit
        recentRuns = try context.fetch(descriptor)
    }

    /// Keeps the history bounded so the store never grows unbounded.
    private func pruneOldRuns() {
        let descriptor = FetchDescriptor<RunRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        guard let all = try? context.fetch(descriptor), all.count > Self.recentRunLimit else { return }
        for record in all.dropFirst(Self.recentRunLimit) {
            context.delete(record)
        }
        persistQuietly()
    }
}
