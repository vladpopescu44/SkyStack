import Foundation
import SwiftData

/// A persisted record of one finished build, shown in the records screen.
@Model
final class RunRecord {
    var date: Date
    var score: Int
    var starsCollected: Int
    var height: Int
    var duration: TimeInterval
    var perfectPlacements: Int
    var builderID: String

    init(summary: RunSummary, date: Date = .now) {
        self.date = date
        self.score = summary.score
        self.starsCollected = summary.starsCollected
        self.height = summary.height
        self.duration = summary.duration
        self.perfectPlacements = summary.perfectPlacements
        self.builderID = summary.builderID
    }

    var builder: BuilderSkin {
        BuilderSkin(rawValue: builderID) ?? .starter
    }
}
