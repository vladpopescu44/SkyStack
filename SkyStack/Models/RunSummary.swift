import Foundation

/// The results of a finished build before they are persisted.
struct RunSummary: Equatable, Sendable {
    var score: Int
    var starsCollected: Int
    /// Number of floors placed on top of the base.
    var height: Int
    var duration: TimeInterval
    var perfectPlacements: Int
    var builderID: String
    var anchors: Int = 0
    var lanterns: Int = 0
    /// True when the lean capacity was exceeded, false when a block missed the tower.
    var toppled: Bool = false
}

/// The outcome of persisting a build, including comparison with the previous bests.
struct RunOutcome: Equatable, Sendable {
    var summary: RunSummary
    var previousBest: Int
    var previousBestHeight: Int
    var isNewBest: Bool
    var isNewHeightRecord: Bool
    var totalStars: Int
}
