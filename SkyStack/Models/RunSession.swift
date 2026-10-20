import Foundation

/// Timed changes produced by advancing a `RunSession`.
struct TickResult: Equatable, Sendable {
    var windWarningStarted = false
    var gustStarted = false
    var gustEnded = false

    static let none = TickResult()
}

/// Why a run ended.
enum RunEnd: Equatable, Sendable {
    /// The block missed the tower entirely.
    case missed
    /// The lean grew past the builder's capacity and the tower fell.
    case toppled
}

/// Everything that happened when a block was dropped.
struct PlacementResult: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case perfect
        case trimmed
        case missed
        case toppled
    }

    var kind: Kind
    /// Height of the tower after this placement.
    var floor: Int
    /// Signed horizontal offset from the previous top after wind slip and lantern.
    var finalOffset: Double
    /// Distance the block slid in the wind.
    var windSlip: Double
    /// Centre and width of the block that stayed on the tower.
    var centerX: Double
    var width: Double
    /// Width of the piece that broke off (zero for perfects).
    var trimmedWidth: Double
    var trimmedSide: WindDirection?
    var scoreGained: Int
    var starsGained: Int
    var isAnchored: Bool
    var usedLantern: Bool
    var lanternLit: Bool
    var cloudArrived: Bool
    var isStorm: Bool
    var stormStarted: Bool
    var stormEnded: Bool

    var isOver: Bool { kind == .missed || kind == .toppled }
    var isPerfect: Bool { kind == .perfect }
}

/// Pure, deterministic state machine for a single build.
/// The SpriteKit scene feeds it time and tap positions; it answers with
/// placements, score, stars and the state of every signature mechanic.
struct RunSession: Equatable, Sendable {
    // MARK: Tunables for the signature mechanics

    /// How much of the lean a perfect placement removes.
    static let perfectLeanDamping: Double = 0.5
    static let firstCloudFloor = 5
    static let cloudGapRange: ClosedRange<Int> = 5...9
    static let calmRange: ClosedRange<Double> = 5...9
    static let stormCalmRange: ClosedRange<Double> = 2.5...4.5

    let loadout: BuilderLoadout
    /// Width of the playfield in scene points. Blocks move within it.
    let playfieldWidth: Double

    private(set) var elapsed: TimeInterval = 0
    private(set) var score = 0
    private(set) var stars = 0
    /// Number of blocks placed on top of the base.
    private(set) var floor = 0
    private(set) var perfectStreak = 0
    private(set) var perfectPlacements = 0
    private(set) var topCenterX: Double
    private(set) var topWidth: Double
    private(set) var isOver = false
    private(set) var endReason: RunEnd?

    // Mechanic 1: wind gusts.
    private(set) var wind = WindState()
    private(set) var gustPlacements = 0

    // Mechanic 2: tower lean, signed; the tower topples past `leanCapacity`.
    private(set) var lean: Double = 0

    // Mechanic 3: cloud anchors.
    private(set) var cloud: CloudAnchor?
    private(set) var floorsUntilCloud = RunSession.firstCloudFloor
    private(set) var anchorsUsed = 0

    // Mechanic 4: storm bands and the Sky Lantern.
    private(set) var stormPerfects = 0
    private(set) var lanternFloorsRemaining = 0
    private(set) var lanternsLit = 0

    private var rng: SeededGenerator

    init(loadout: BuilderLoadout, playfieldWidth: Double = 390, seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        self.loadout = loadout
        self.playfieldWidth = playfieldWidth
        topCenterX = playfieldWidth / 2
        topWidth = playfieldWidth * loadout.foundationFraction
        rng = SeededGenerator(seed: seed)
    }

    // MARK: - Derived state

    var baseWidth: Double { playfieldWidth * loadout.foundationFraction }
    /// Floor number of the block currently in the air.
    var currentFloor: Int { floor + 1 }
    var isStorm: Bool { StormBand.isStorm(atFloor: currentFloor) }
    var floorsUntilStorm: Int? { StormBand.floorsUntilStorm(from: currentFloor) }
    var isLanternActive: Bool { lanternFloorsRemaining > 0 }
    var blockSpeed: Double { GameBalance.blockSpeed(atFloor: floor) }
    var leanCapacity: Double { loadout.leanCapacity }
    /// Lean in `-1...1` relative to the capacity, for the HUD meter.
    var normalizedLean: Double { max(-1, min(1, lean / leanCapacity)) }
    /// Velocity the current gust adds to the moving block after Windbreak.
    var windPush: Double { wind.pushVelocity * loadout.windbreakFactor }
    /// Distance the next placed block would slide in the current gust.
    var currentWindSlip: Double {
        guard wind.isGusting else { return 0 }
        return wind.direction.sign * wind.strength * GameBalance.windSlip * loadout.windbreakFactor
    }

    // MARK: - Time

    /// Advances the clock, the wind cycle and the cloud drift.
    mutating func advance(by dt: TimeInterval) -> TickResult {
        guard !isOver, dt > 0 else { return .none }
        elapsed += dt

        var result = TickResult()
        wind.remaining -= dt
        if wind.remaining <= 0 {
            switch wind.phase {
            case .calm:
                wind.phase = .warning
                wind.direction = rng.next() % 2 == 0 ? .left : .right
                wind.strength = isStorm ? WindState.stormStrength : 1
                wind.remaining = WindState.warningDuration
                result.windWarningStarted = true
            case .warning:
                wind.phase = .gusting
                wind.remaining = WindState.gustDuration
                result.gustStarted = true
            case .gusting:
                wind.phase = .calm
                wind.remaining = nextCalmDuration()
                result.gustEnded = true
            }
        }

        if var active = cloud {
            active.drift(by: dt, within: playfieldWidth)
            cloud = active
        }
        return result
    }

    private mutating func nextCalmDuration() -> TimeInterval {
        let range = isStorm ? Self.stormCalmRange : Self.calmRange
        return range.lowerBound + (range.upperBound - range.lowerBound) * rng.unit()
    }

    // MARK: - Placement

    /// Drops the moving block whose centre is at `blockCenterX`.
    /// Returns `nil` once the run is over.
    mutating func place(blockCenterX: Double) -> PlacementResult? {
        guard !isOver else { return nil }

        let previousFloor = floor
        let rawOffset = blockCenterX - topCenterX
        var slip = currentWindSlip
        var usedLantern = false
        var offset = rawOffset + slip

        if lanternFloorsRemaining > 0 {
            // The lantern guides the block onto the centre regardless of wind.
            lanternFloorsRemaining -= 1
            usedLantern = true
            slip = 0
            offset = 0
        }

        let isPerfect = abs(offset) <= loadout.perfectTolerance
        if isPerfect {
            offset = 0
        }

        let overlap = topWidth - abs(offset)
        if !isPerfect, overlap < GameBalance.minimumOverlap {
            isOver = true
            endReason = .missed
            perfectStreak = 0
            return PlacementResult(
                kind: .missed, floor: floor, finalOffset: offset, windSlip: slip,
                centerX: blockCenterX + slip, width: topWidth, trimmedWidth: topWidth,
                trimmedSide: offset < 0 ? .left : .right, scoreGained: 0, starsGained: 0,
                isAnchored: false, usedLantern: usedLantern, lanternLit: false, cloudArrived: false,
                isStorm: isStorm, stormStarted: false, stormEnded: false
            )
        }

        floor += 1
        let newWidthBeforeAnchor = isPerfect ? topWidth : overlap
        var newWidth = newWidthBeforeAnchor
        let newCenter = isPerfect ? topCenterX : topCenterX + offset / 2
        let trimmedWidth = topWidth - newWidthBeforeAnchor
        let trimmedSide: WindDirection? = trimmedWidth > 0 ? (offset < 0 ? .left : .right) : nil

        if wind.isGusting {
            gustPlacements += 1
        }

        // Mechanic 2: lean.
        if isPerfect {
            perfectStreak += 1
            perfectPlacements += 1
            lean *= Self.perfectLeanDamping
        } else {
            perfectStreak = 0
            lean += offset / (baseWidth * 0.5)
        }

        // Mechanic 3: cloud anchor.
        var isAnchored = false
        if let active = cloud, active.covers(newCenter) {
            isAnchored = true
            anchorsUsed += 1
            newWidth = max(newWidth, baseWidth * GameBalance.anchorWidthFraction)
            lean = 0
            cloud = nil
        }

        topCenterX = newCenter
        topWidth = newWidth

        if abs(lean) > leanCapacity {
            isOver = true
            endReason = .toppled
            return PlacementResult(
                kind: .toppled, floor: floor, finalOffset: offset, windSlip: slip,
                centerX: newCenter, width: newWidth, trimmedWidth: trimmedWidth, trimmedSide: trimmedSide,
                scoreGained: 0, starsGained: 0, isAnchored: isAnchored, usedLantern: usedLantern,
                lanternLit: false, cloudArrived: false, isStorm: StormBand.isStorm(atFloor: floor),
                stormStarted: false, stormEnded: false
            )
        }

        // Mechanic 4: storm bands and the lantern.
        let storm = StormBand.isStorm(atFloor: floor)
        let stormStarted = storm && !StormBand.isStorm(atFloor: previousFloor)
        let stormEnded = !storm && previousFloor > 0 && StormBand.isStorm(atFloor: previousFloor)
        var lanternLit = false
        if storm, isPerfect, !usedLantern {
            stormPerfects += 1
            if stormPerfects >= SkyLantern.perfectsToCharge {
                stormPerfects = 0
                lanternFloorsRemaining = SkyLantern.floors
                lanternsLit += 1
                lanternLit = true
            }
        } else if !isPerfect {
            stormPerfects = 0
        }
        if stormEnded {
            stormPerfects = 0
        }

        // Rewards.
        let scoreGained = GameBalance.placementScore(perfectStreak: isPerfect ? perfectStreak : 0, isStorm: storm)
        let starsGained = GameBalance.placementStars(
            isPerfect: isPerfect, isAnchored: isAnchored, isStorm: storm, multiplier: loadout.starMultiplier
        )
        score += scoreGained
        stars += starsGained

        // Cloud schedule: existing clouds drift away after a few floors, new ones arrive on a cadence.
        var cloudArrived = false
        if var active = cloud {
            active.floorsRemaining -= 1
            cloud = active.floorsRemaining > 0 ? active : nil
        } else {
            floorsUntilCloud -= 1
            if floorsUntilCloud <= 0 {
                spawnCloud()
                cloudArrived = true
                let span = Self.cloudGapRange
                floorsUntilCloud = span.lowerBound + Int(rng.next() % UInt64(span.upperBound - span.lowerBound + 1))
            }
        }

        return PlacementResult(
            kind: isPerfect ? .perfect : .trimmed, floor: floor, finalOffset: offset, windSlip: slip,
            centerX: newCenter, width: newWidth, trimmedWidth: trimmedWidth, trimmedSide: trimmedSide,
            scoreGained: scoreGained, starsGained: starsGained, isAnchored: isAnchored,
            usedLantern: usedLantern, lanternLit: lanternLit, cloudArrived: cloudArrived,
            isStorm: storm, stormStarted: stormStarted, stormEnded: stormEnded
        )
    }

    private mutating func spawnCloud() {
        let width = playfieldWidth * CloudAnchor.widthFraction
        let minX = width / 2
        let maxX = max(minX, playfieldWidth - width / 2)
        let centerX = minX + (maxX - minX) * rng.unit()
        let velocity = (rng.next() % 2 == 0 ? -1.0 : 1.0) * CloudAnchor.speed
        cloud = CloudAnchor(centerX: centerX, width: width, velocity: velocity)
    }

    // MARK: - Summary

    /// Snapshot used to persist the finished build.
    var summary: RunSummary {
        RunSummary(
            score: score,
            starsCollected: stars,
            height: floor,
            duration: elapsed,
            perfectPlacements: perfectPlacements,
            builderID: loadout.skin.rawValue,
            anchors: anchorsUsed,
            lanterns: lanternsLit,
            toppled: endReason == .toppled
        )
    }
}
