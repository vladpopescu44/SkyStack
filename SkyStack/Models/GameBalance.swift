import Foundation

/// Tunable constants and pure formulas behind the tower's difficulty curve.
/// Everything here is framework-free so the balance can be unit tested.
enum GameBalance {
    /// Height of every block in scene points.
    static let blockHeight: Double = 34
    /// A block that overlaps the tower by less than this falls off entirely.
    static let minimumOverlap: Double = 10
    /// Horizontal speed of the first moving block, points per second.
    static let initialBlockSpeed: Double = 150
    /// Speed added per placed floor.
    static let speedPerFloor: Double = 5.5
    static let maximumBlockSpeed: Double = 430
    /// Extra velocity a normal gust adds to the moving block, points per second.
    static let windPush: Double = 95
    /// Distance a freshly placed block slides in a normal gust before settling.
    static let windSlip: Double = 9
    /// Fraction of the base width a cloud anchor restores.
    static let anchorWidthFraction: Double = 0.85

    static let scorePerFloor = 10
    static let perfectScoreBonus = 15
    static let maximumStreakBonus = 5
    static let starsPerFloor = 1
    static let perfectStars = 1
    static let anchorStars = 3

    /// Delay before the results screen appears after the tower falls.
    static let gameOverDelay: TimeInterval = 0.9

    /// Horizontal speed of the block being placed on top of `floor` placed blocks.
    static func blockSpeed(atFloor floor: Int) -> Double {
        min(initialBlockSpeed + speedPerFloor * Double(max(floor, 0)), maximumBlockSpeed)
    }

    /// Score awarded for one placed floor. Storm floors are worth double.
    static func placementScore(perfectStreak: Int, isStorm: Bool) -> Int {
        var score = scorePerFloor
        if perfectStreak > 0 {
            score += perfectScoreBonus * min(perfectStreak, maximumStreakBonus)
        }
        return isStorm ? score * 2 : score
    }

    /// Stars awarded for one placed floor after the builder's multiplier.
    static func placementStars(isPerfect: Bool, isAnchored: Bool, isStorm: Bool, multiplier: Double) -> Int {
        var stars = starsPerFloor + (isPerfect ? perfectStars : 0) + (isAnchored ? anchorStars : 0)
        if isStorm {
            stars *= StormBand.starMultiplier
        }
        return max(1, Int((Double(stars) * multiplier).rounded()))
    }
}
