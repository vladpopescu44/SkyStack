import Foundation
import Testing
@testable import SkyStack

/// Tests for the four signature mechanics: wind gusts, tower lean, cloud anchors and storm bands.
@MainActor
struct MechanicsTests {
    private func session(seed: UInt64 = 7, loadout: BuilderLoadout? = nil) -> RunSession {
        RunSession(loadout: loadout ?? .starter, playfieldWidth: 390, seed: seed)
    }

    private func advance(_ session: inout RunSession, seconds: TimeInterval, step: TimeInterval = 1.0 / 60.0) -> [TickResult] {
        var results: [TickResult] = []
        var remaining = seconds
        while remaining > 0 {
            let dt = min(step, remaining)
            results.append(session.advance(by: dt))
            remaining -= dt
        }
        return results
    }

    /// Places `count` perfect blocks straight on the current centre.
    private func placePerfects(_ session: inout RunSession, count: Int) {
        for _ in 0..<count {
            let result = session.place(blockCenterX: session.topCenterX)
            #expect(result?.isPerfect == true)
        }
    }

    // MARK: - Mechanic 1: wind gusts

    @Test func windIsTelegraphedThenGustsThenCalms() {
        var run = session()
        #expect(run.wind.phase == .calm)
        #expect(run.windPush == 0)
        #expect(run.currentWindSlip == 0)

        let warning = advance(&run, seconds: WindState.firstCalmDuration + 0.05)
        #expect(warning.contains { $0.windWarningStarted })
        #expect(run.wind.phase == .warning)
        #expect(run.wind.strength == 1)
        #expect(run.windPush == 0, "The warning phase must not push yet")

        let gust = advance(&run, seconds: WindState.warningDuration + 0.05)
        #expect(gust.contains { $0.gustStarted })
        #expect(run.wind.phase == .gusting)
        let sign = run.wind.direction.sign
        #expect(run.windPush == sign * GameBalance.windPush)
        #expect(run.currentWindSlip == sign * GameBalance.windSlip)

        let calm = advance(&run, seconds: WindState.gustDuration + 0.05)
        #expect(calm.contains { $0.gustEnded })
        #expect(run.wind.phase == .calm)
        #expect(run.wind.remaining >= RunSession.calmRange.lowerBound - 0.1)
        #expect(run.wind.remaining <= RunSession.calmRange.upperBound)
    }

    @Test func gustsMakePlacedBlocksSlip() {
        var run = session()
        _ = advance(&run, seconds: WindState.firstCalmDuration + WindState.warningDuration + 0.1)
        #expect(run.wind.isGusting)
        let slip = run.currentWindSlip
        let width = run.topWidth

        // Dropped dead centre, the block still slides past the perfect zone.
        let result = run.place(blockCenterX: run.topCenterX)!
        #expect(result.kind == .trimmed)
        #expect(result.windSlip == slip)
        #expect(result.finalOffset == slip)
        #expect(abs(result.width - (width - abs(slip))) < 0.0001)
        #expect(run.gustPlacements == 1)

        // Compensating against the wind lands a perfect.
        let compensated = run.place(blockCenterX: run.topCenterX - slip)!
        #expect(compensated.kind == .perfect)
    }

    @Test func windbreakWeakensGusts() {
        var loadout = BuilderLoadout.starter
        loadout.setLevel(5, for: .windbreak)
        var run = session(loadout: loadout)
        _ = advance(&run, seconds: WindState.firstCalmDuration + WindState.warningDuration + 0.1)
        #expect(run.wind.isGusting)
        #expect(abs(run.currentWindSlip) < BuilderLoadout.starter.perfectTolerance)
        #expect(abs(run.windPush) < GameBalance.windPush * 0.5)

        let result = run.place(blockCenterX: run.topCenterX)!
        #expect(result.kind == .perfect)
    }

    // MARK: - Mechanic 2: tower lean

    @Test func leanAccumulatesAndTopplesPastCapacity() {
        var run = session()
        let halfBase = run.baseWidth * 0.5
        _ = run.place(blockCenterX: run.topCenterX + 40)
        #expect(abs(run.lean - 40 / halfBase) < 0.0001)
        _ = run.place(blockCenterX: run.topCenterX + 40)
        #expect(abs(run.lean - 80 / halfBase) < 0.0001)
        #expect(run.isOver == false)

        let result = run.place(blockCenterX: run.topCenterX + 40)!
        #expect(result.kind == .toppled)
        #expect(result.isOver)
        #expect(result.scoreGained == 0)
        #expect(result.starsGained == 0)
        #expect(run.isOver)
        #expect(run.endReason == .toppled)
        #expect(run.floor == 3)
        #expect(run.summary.toppled)
        #expect(run.normalizedLean == 1)
    }

    @Test func leanIsSignedAndPerfectsPullItBack() {
        var run = session()
        _ = run.place(blockCenterX: run.topCenterX - 40)
        #expect(run.lean < 0)
        let before = run.lean
        _ = run.place(blockCenterX: run.topCenterX + 40)
        #expect(abs(run.lean) < 0.0001, "Equal offsets on both sides cancel out")

        _ = run.place(blockCenterX: run.topCenterX + 40)
        let leaning = run.lean
        #expect(leaning > 0)
        _ = run.place(blockCenterX: run.topCenterX)
        #expect(abs(run.lean - leaning * RunSession.perfectLeanDamping) < 0.0001)
        #expect(abs(before) > 0)
    }

    @Test func ballastRaisesTheLeanCapacity() {
        var loadout = BuilderLoadout.starter
        loadout.setLevel(5, for: .ballast)
        var run = session(loadout: loadout)
        for _ in 0..<3 {
            _ = run.place(blockCenterX: run.topCenterX + 40)
        }
        #expect(run.isOver == false)
        #expect(run.lean > 1)
        #expect(run.normalizedLean < 1)
    }

    // MARK: - Mechanic 3: cloud anchors

    @Test func cloudArrivesOnScheduleAndDriftsWithinThePlayfield() {
        var run = session()
        for index in 1..<RunSession.firstCloudFloor {
            let result = run.place(blockCenterX: run.topCenterX)!
            #expect(result.cloudArrived == false, "No cloud before floor \(RunSession.firstCloudFloor), got one at \(index)")
            #expect(run.cloud == nil)
        }
        let arrival = run.place(blockCenterX: run.topCenterX)!
        #expect(arrival.cloudArrived)
        let cloud = try! #require(run.cloud)
        #expect(abs(cloud.width - 390 * CloudAnchor.widthFraction) < 0.0001)
        #expect(cloud.minX >= 0 && cloud.maxX <= 390)
        #expect(cloud.floorsRemaining == CloudAnchor.floorsVisible)

        _ = advance(&run, seconds: 20)
        let drifted = try! #require(run.cloud)
        #expect(drifted.minX >= -0.0001 && drifted.maxX <= 390.0001)
        #expect(drifted.centerX != cloud.centerX)
    }

    @Test func placingUnderTheCloudRestoresWidthAndResetsLean() {
        var run = session(seed: 3)
        placePerfects(&run, count: RunSession.firstCloudFloor)
        #expect(run.cloud != nil)

        // Wait until the cloud drifts close enough to reach without missing, yet outside the perfect zone.
        var attempts = 0
        while let cloud = run.cloud, !(8...40).contains(abs(cloud.centerX - run.topCenterX)), attempts < 60 * 40 {
            _ = run.advance(by: 1.0 / 60.0)
            attempts += 1
        }
        let cloud = try! #require(run.cloud)
        #expect((8...40).contains(abs(cloud.centerX - run.topCenterX)), "Cloud never came within reach")

        // Aim the kept part's centre at the cloud, accounting for any wind slip in flight.
        let finalOffset = 2 * (cloud.centerX - run.topCenterX)
        let result = run.place(blockCenterX: run.topCenterX + finalOffset - run.currentWindSlip)!
        #expect(result.kind == .trimmed)
        #expect(result.isAnchored)
        #expect(abs(result.width - run.baseWidth * GameBalance.anchorWidthFraction) < 0.0001)
        #expect(run.lean == 0)
        #expect(run.cloud == nil)
        #expect(run.anchorsUsed == 1)
        #expect(result.starsGained == GameBalance.starsPerFloor + GameBalance.anchorStars)
        #expect(run.summary.anchors == 1)
    }

    @Test func cloudDriftsAwayAfterAFewFloors() {
        var run = session(seed: 5)
        placePerfects(&run, count: RunSession.firstCloudFloor)
        #expect(run.cloud != nil)
        placePerfects(&run, count: CloudAnchor.floorsVisible)
        #expect(run.cloud == nil)
    }

    // MARK: - Mechanic 4: storm bands and the Sky Lantern

    @Test func stormsDoubleRewardsAndLightTheLantern() {
        var run = session(seed: 11)
        placePerfects(&run, count: StormBand.firstFloor - 1)
        #expect(run.isStorm, "The tenth block is placed inside the first storm")
        #expect(run.floorsUntilStorm == nil)

        let first = run.place(blockCenterX: run.topCenterX)!
        #expect(first.isStorm)
        #expect(first.stormStarted)
        #expect(first.scoreGained == GameBalance.placementScore(perfectStreak: 10, isStorm: true))
        #expect(first.starsGained >= 4)
        #expect(run.stormPerfects == 1)

        let second = run.place(blockCenterX: run.topCenterX)!
        #expect(second.lanternLit == false)
        let third = run.place(blockCenterX: run.topCenterX)!
        #expect(third.lanternLit)
        #expect(run.isLanternActive)
        #expect(run.lanternFloorsRemaining == SkyLantern.floors)
        #expect(run.lanternsLit == 1)
        #expect(run.stormPerfects == 0)

        // The lantern centres wildly off blocks, keeps the width, and does not count toward the next lantern.
        let width = run.topWidth
        for remaining in stride(from: SkyLantern.floors - 1, through: 0, by: -1) {
            let guided = run.place(blockCenterX: run.topCenterX + 60)!
            #expect(guided.kind == .perfect)
            #expect(guided.usedLantern)
            #expect(guided.finalOffset == 0)
            #expect(run.lanternFloorsRemaining == remaining)
            #expect(run.stormPerfects == 0)
        }
        #expect(run.isLanternActive == false)
        #expect(abs(run.topWidth - width) < 0.0001)
        #expect(run.floor == 15)
        #expect(run.isStorm == false, "Floor 16 is calm again")
        #expect(run.summary.lanterns == 1)
    }

    @Test func stormEndsAfterItsBandAndResetsStormPerfects() {
        var run = session(seed: 13)
        placePerfects(&run, count: StormBand.firstFloor - 1)
        // Two perfects inside the storm, then a trimmed drop breaks the chain.
        placePerfects(&run, count: 2)
        #expect(run.stormPerfects == 2)
        let broken = run.place(blockCenterX: run.topCenterX + 20)!
        #expect(broken.isStorm)
        #expect(run.stormPerfects == 0)

        placePerfects(&run, count: 2)
        let calm = run.place(blockCenterX: run.topCenterX)!
        #expect(calm.floor == 15)
        #expect(calm.isStorm == false)
        #expect(calm.stormEnded)
        #expect(run.floorsUntilStorm == StormBand.period - StormBand.length - 1)
    }

    @Test func stormGustsAreStronger() {
        var run = session(seed: 17)
        placePerfects(&run, count: StormBand.firstFloor - 1)
        #expect(run.isStorm)
        _ = advance(&run, seconds: WindState.firstCalmDuration + 0.05)
        #expect(run.wind.phase == .warning)
        #expect(run.wind.strength == WindState.stormStrength)
        _ = advance(&run, seconds: WindState.warningDuration + 0.05)
        #expect(abs(run.windPush) > GameBalance.windPush)
        _ = advance(&run, seconds: WindState.gustDuration + 0.05)
        #expect(run.wind.phase == .calm)
        #expect(run.wind.remaining <= RunSession.stormCalmRange.upperBound)
    }

    @Test func seededSessionsAreDeterministic() {
        var first = session(seed: 99)
        var second = session(seed: 99)
        for _ in 0..<12 {
            _ = advance(&first, seconds: 2)
            _ = advance(&second, seconds: 2)
            _ = first.place(blockCenterX: first.topCenterX + 7)
            _ = second.place(blockCenterX: second.topCenterX + 7)
        }
        #expect(first == second)
    }
}
