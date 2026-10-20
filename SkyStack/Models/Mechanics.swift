import Foundation

/// Which way a gust pushes the block.
enum WindDirection: Int, Equatable, Sendable {
    case left = -1
    case right = 1

    var sign: Double { Double(rawValue) }

    var title: String {
        self == .left ? "left" : "right"
    }

    var systemImage: String {
        self == .left ? "arrow.left" : "arrow.right"
    }
}

/// Mechanic 1: telegraphed wind gusts.
/// Calm → warning banner → gust that pushes the moving block and makes placed blocks slip.
struct WindState: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        case calm
        case warning
        case gusting
    }

    static let warningDuration: TimeInterval = 1.6
    static let gustDuration: TimeInterval = 4.5
    static let firstCalmDuration: TimeInterval = 7
    /// Gust strength multiplier inside a storm band.
    static let stormStrength: Double = 1.6

    var phase: Phase = .calm
    var direction: WindDirection = .right
    var strength: Double = 1
    var remaining: TimeInterval = WindState.firstCalmDuration

    var isGusting: Bool { phase == .gusting }

    /// Velocity added to the moving block while gusting, before the Windbreak upgrade.
    var pushVelocity: Double {
        isGusting ? direction.sign * strength * GameBalance.windPush : 0
    }
}

/// Mechanic 3: a drifting cloud at the tower's top.
/// Placing a block while the cloud covers its centre anchors the tower:
/// width is restored and the lean resets.
struct CloudAnchor: Equatable, Sendable {
    static let widthFraction: Double = 0.30
    static let speed: Double = 38
    /// How many placements the cloud stays before drifting away.
    static let floorsVisible = 4

    var centerX: Double
    var width: Double
    var velocity: Double
    var floorsRemaining: Int = CloudAnchor.floorsVisible

    var minX: Double { centerX - width / 2 }
    var maxX: Double { centerX + width / 2 }

    func covers(_ x: Double) -> Bool {
        x >= minX && x <= maxX
    }

    /// Moves the cloud and bounces it off the playfield edges.
    mutating func drift(by dt: TimeInterval, within playfieldWidth: Double) {
        centerX += velocity * dt
        let lower = width / 2
        let upper = max(lower, playfieldWidth - width / 2)
        if centerX < lower {
            centerX = lower
            velocity = abs(velocity)
        } else if centerX > upper {
            centerX = upper
            velocity = -abs(velocity)
        }
    }
}

/// Mechanic 4: storm bands. Every `period` floors a band of `length` floors
/// brings stronger wind and doubles stars; perfects inside charge the Sky Lantern.
enum StormBand {
    static let firstFloor = 10
    static let period = 12
    static let length = 5
    static let warningFloors = 2
    static let starMultiplier = 2

    static func isStorm(atFloor floor: Int) -> Bool {
        guard floor >= firstFloor else { return false }
        return (floor - firstFloor) % period < length
    }

    /// Floors until the next storm begins, or `nil` when `floor` is inside one.
    static func floorsUntilStorm(from floor: Int) -> Int? {
        if isStorm(atFloor: floor) { return nil }
        if floor < firstFloor { return firstFloor - floor }
        return period - (floor - firstFloor) % period
    }
}

/// The reward for mastering a storm: the next blocks centre themselves.
enum SkyLantern {
    static let perfectsToCharge = 3
    static let floors = 3
}
