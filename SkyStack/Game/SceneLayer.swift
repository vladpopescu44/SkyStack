import Foundation

/// z-positions for the tower scene so draw order stays consistent.
enum SceneLayer {
    static let sky: CGFloat = 0
    static let stars: CGFloat = 1
    static let farClouds: CGFloat = 2
    static let stormTint: CGFloat = 3
    static let pillar: CGFloat = 4
    static let cloudAnchor: CGFloat = 5
    static let tower: CGFloat = 6
    static let debris: CGFloat = 7
    static let movingBlock: CGFloat = 8
    static let builder: CGFloat = 9
    static let effects: CGFloat = 10
    static let weather: CGFloat = 11
    static let flash: CGFloat = 12
}
