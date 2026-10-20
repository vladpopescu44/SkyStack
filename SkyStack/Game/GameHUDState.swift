import Foundation

/// The values the SwiftUI HUD displays, mirrored from the running scene.
struct GameHUDState: Equatable, Sendable {
    var score = 0
    var height = 0
    var stars = 0
    var elapsed: TimeInterval = 0
    /// Lean in `-1...1` relative to the capacity; the tower falls at the ends.
    var lean: Double = 0
    var perfectStreak = 0

    var windPhase: WindState.Phase = .calm
    var windDirection: WindDirection = .right
    var windRemaining: TimeInterval = 0
    var isStormWind = false

    var isStorm = false
    var floorsUntilStorm: Int?
    var stormPerfects = 0
    var lanternFloors = 0
    var hasCloud = false

    init(loadout: BuilderLoadout) {
        floorsUntilStorm = StormBand.floorsUntilStorm(from: 1)
    }

    init(session: RunSession) {
        score = session.score
        height = session.floor
        stars = session.stars
        elapsed = session.elapsed
        lean = session.normalizedLean
        perfectStreak = session.perfectStreak
        windPhase = session.wind.phase
        windDirection = session.wind.direction
        windRemaining = session.wind.remaining
        isStormWind = session.wind.strength > 1
        isStorm = session.isStorm
        floorsUntilStorm = session.floorsUntilStorm
        stormPerfects = session.stormPerfects
        lanternFloors = session.lanternFloorsRemaining
        hasCloud = session.cloud != nil
    }
}

/// Discrete gameplay moments the view model reacts to (haptics, flashes).
enum GameEvent: Equatable, Sendable {
    case placed(perfect: Bool)
    case anchored
    case lanternLit
    case windWarning(WindDirection)
    case gustStarted
    case stormStarted
    case stormEnded
    case toppled
    case missed
}
