import Foundation

/// Value snapshot of lifetime statistics used to evaluate achievements.
struct PlayerStats: Equatable, Sendable {
    var bestScore = 0
    var bestHeight = 0
    var totalRuns = 0
    var totalStarsCollected = 0
    var totalFloors = 0
    var totalPerfects = 0
    var totalAnchors = 0
    var totalLanterns = 0
    var unlockedBuilderCount = 1
    var maxedUpgradeCount = 0
}

/// A milestone the player can reach through play.
struct Achievement: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let isUnlocked: Bool
    /// Progress in `0...1` toward unlocking.
    let progress: Double
}

/// Defines and evaluates all achievements. Evaluation is pure so it can be tested.
enum AchievementCatalog {
    private struct Definition {
        let id: String
        let title: String
        let detail: String
        let systemImage: String
        let target: Double
        let value: @Sendable (PlayerStats) -> Double
    }

    private static let definitions: [Definition] = [
        Definition(id: "firstRun", title: "Groundbreaking", detail: "Finish your first build.",
                   systemImage: "flag.checkered", target: 1) { Double($0.totalRuns) },
        Definition(id: "height20", title: "Above the Clouds", detail: "Stack 20 floors in a single build.",
                   systemImage: "cloud.fill", target: 20) { Double($0.bestHeight) },
        Definition(id: "height50", title: "Stratosphere", detail: "Stack 50 floors in a single build.",
                   systemImage: "airplane", target: 50) { Double($0.bestHeight) },
        Definition(id: "score1000", title: "Skyline", detail: "Score 1,000 points in a single build.",
                   systemImage: "building.2.fill", target: 1000) { Double($0.bestScore) },
        Definition(id: "score5000", title: "Sky Legend", detail: "Score 5,000 points in a single build.",
                   systemImage: "crown.fill", target: 5000) { Double($0.bestScore) },
        Definition(id: "perfects100", title: "Steady Hands", detail: "Land 100 perfect placements in total.",
                   systemImage: "scope", target: 100) { Double($0.totalPerfects) },
        Definition(id: "stars500", title: "Star Collector", detail: "Collect 500 stars in total.",
                   systemImage: "star.fill", target: 500) { Double($0.totalStarsCollected) },
        Definition(id: "runs25", title: "Site Foreman", detail: "Finish 25 builds.",
                   systemImage: "repeat", target: 25) { Double($0.totalRuns) },
        Definition(id: "anchors10", title: "Cloud Walker", detail: "Anchor the tower to 10 clouds.",
                   systemImage: "cloud.bolt.fill", target: 10) { Double($0.totalAnchors) },
        Definition(id: "lanterns5", title: "Lantern Keeper", detail: "Light the Sky Lantern 5 times.",
                   systemImage: "lightbulb.max.fill", target: 5) { Double($0.totalLanterns) },
        Definition(id: "builders3", title: "Full Crew", detail: "Unlock 3 builders.",
                   systemImage: "person.3.fill", target: 3) { Double($0.unlockedBuilderCount) },
        Definition(id: "maxUpgrade", title: "Master Builder", detail: "Max out any upgrade.",
                   systemImage: "wrench.and.screwdriver.fill", target: 1) { Double($0.maxedUpgradeCount) }
    ]

    static func evaluate(_ stats: PlayerStats) -> [Achievement] {
        definitions.map { definition in
            let value = definition.value(stats)
            let progress = min(max(value / definition.target, 0), 1)
            return Achievement(
                id: definition.id,
                title: definition.title,
                detail: definition.detail,
                systemImage: definition.systemImage,
                isUnlocked: value >= definition.target,
                progress: progress
            )
        }
    }
}
