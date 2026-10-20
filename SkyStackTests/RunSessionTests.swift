import Foundation
import Testing
@testable import SkyStack

/// Tests for the framework-free build simulation: dropping, trimming, missing and scoring.
@MainActor
struct RunSessionTests {
    private func session(seed: UInt64 = 7) -> RunSession {
        RunSession(loadout: .starter, playfieldWidth: 390, seed: seed)
    }

    @Test func freshSessionStartsCentredOnTheBase() {
        let run = session()
        #expect(run.floor == 0)
        #expect(run.currentFloor == 1)
        #expect(run.topCenterX == 195)
        #expect(abs(run.topWidth - 390 * 0.58) < 0.0001)
        #expect(run.score == 0)
        #expect(run.stars == 0)
        #expect(run.lean == 0)
        #expect(run.isOver == false)
        #expect(run.isStorm == false)
        #expect(run.floorsUntilStorm == 9)
        #expect(run.cloud == nil)
        #expect(run.wind.phase == .calm)
    }

    @Test func advancingAccumulatesTimeOnly() {
        var run = session()
        _ = run.advance(by: 1)
        #expect(run.elapsed == 1)
        #expect(run.score == 0)
        #expect(run.advance(by: 0) == .none)
        #expect(run.advance(by: -1) == .none)
        #expect(run.elapsed == 1)
    }

    @Test func perfectDropKeepsWidthAndCentre() {
        var run = session()
        let result = run.place(blockCenterX: 195 + 3)!
        #expect(result.kind == .perfect)
        #expect(result.floor == 1)
        #expect(result.finalOffset == 0)
        #expect(result.trimmedWidth == 0)
        #expect(result.trimmedSide == nil)
        #expect(result.scoreGained == 25)
        #expect(result.starsGained == 2)
        #expect(run.topCenterX == 195)
        #expect(abs(run.topWidth - 390 * 0.58) < 0.0001)
        #expect(run.perfectStreak == 1)
        #expect(run.perfectPlacements == 1)
        #expect(run.score == 25)
        #expect(run.stars == 2)
    }

    @Test func offCentreDropTrimsTheOverhang() {
        var run = session()
        let width = run.topWidth
        let result = run.place(blockCenterX: 195 + 30)!
        #expect(result.kind == .trimmed)
        #expect(abs(result.width - (width - 30)) < 0.0001)
        #expect(abs(result.trimmedWidth - 30) < 0.0001)
        #expect(result.trimmedSide == .right)
        #expect(abs(result.centerX - 210) < 0.0001)
        #expect(result.scoreGained == 10)
        #expect(result.starsGained == 1)
        #expect(run.perfectStreak == 0)
        #expect(abs(run.topWidth - (width - 30)) < 0.0001)
        #expect(abs(run.topCenterX - 210) < 0.0001)
        #expect(abs(run.lean - 30 / (width * 0.5)) < 0.0001)

        let left = run.place(blockCenterX: 210 - 20)!
        #expect(left.trimmedSide == .left)
        #expect(abs(run.topCenterX - 200) < 0.0001)
    }

    @Test func missingTheTowerEndsTheBuild() {
        var run = session()
        let result = run.place(blockCenterX: 195 + 300)!
        #expect(result.kind == .missed)
        #expect(result.isOver)
        #expect(result.floor == 0)
        #expect(run.isOver)
        #expect(run.endReason == .missed)
        #expect(run.floor == 0)
        #expect(run.place(blockCenterX: 195) == nil)
        #expect(run.advance(by: 1) == .none)
        #expect(run.summary.toppled == false)
    }

    @Test func thinOverlapCountsAsMiss() {
        var run = session()
        let width = run.topWidth
        let result = run.place(blockCenterX: 195 + width - GameBalance.minimumOverlap + 1)!
        #expect(result.kind == .missed)
    }

    @Test func perfectStreaksRaiseTheScore() {
        var run = session()
        _ = run.place(blockCenterX: 195)
        _ = run.place(blockCenterX: 195)
        let third = run.place(blockCenterX: 195)!
        #expect(third.scoreGained == 55)
        #expect(run.perfectStreak == 3)

        let broken = run.place(blockCenterX: 195 + 25)!
        #expect(broken.kind == .trimmed)
        #expect(run.perfectStreak == 0)
        #expect(broken.scoreGained == 10)
    }

    @Test func blockSpeedRisesAsTheTowerGrows() {
        var run = session()
        let initial = run.blockSpeed
        for _ in 0..<8 {
            _ = run.place(blockCenterX: run.topCenterX)
        }
        #expect(run.blockSpeed > initial)
    }

    @Test func summaryReflectsState() {
        var run = session()
        _ = run.advance(by: 12)
        _ = run.place(blockCenterX: 195)
        _ = run.place(blockCenterX: 195 + 20)
        let summary = run.summary
        #expect(summary.duration == 12)
        #expect(summary.height == 2)
        #expect(summary.perfectPlacements == 1)
        #expect(summary.score == run.score)
        #expect(summary.starsCollected == run.stars)
        #expect(summary.builderID == BuilderSkin.starter.rawValue)
        #expect(summary.anchors == 0)
        #expect(summary.lanterns == 0)
    }

    @Test func loadoutShapesTheSession() {
        var loadout = BuilderLoadout.starter
        loadout.setLevel(5, for: .foundation)
        loadout.setLevel(5, for: .precision)
        loadout.setLevel(2, for: .charm)
        var run = RunSession(loadout: loadout, playfieldWidth: 390, seed: 1)
        #expect(abs(run.baseWidth - 390 * 0.78) < 0.0001)

        // 14 points off centre is still perfect with maxed precision...
        let result = run.place(blockCenterX: 195 + 14)!
        #expect(result.kind == .perfect)
        // ...and stars are multiplied by the charm.
        #expect(result.starsGained == Int((2 * 1.6).rounded()))
    }
}
