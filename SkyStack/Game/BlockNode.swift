import SpriteKit

/// One tower block: a 9-slice sprite with little windows, resizable to any width.
@MainActor
final class BlockNode: SKNode {
    static let height = CGFloat(GameBalance.blockHeight)

    let body: SKSpriteNode
    let color: RGB
    private let textureKey: String
    private var windows: [SKShapeNode] = []
    private(set) var blockWidth: CGFloat
    /// Position in world coordinates, kept so the tower can re-pivot around its top.
    var worldCenter: CGPoint = .zero

    init(width: CGFloat, color: RGB, textureKey: String) {
        self.color = color
        self.textureKey = textureKey
        blockWidth = width
        body = SKSpriteNode(texture: TextureFactory.block(color: color, key: textureKey))
        body.centerRect = TextureFactory.blockCenterRect
        body.size = CGSize(width: width, height: Self.height)
        super.init()
        addChild(body)
        layoutWindows()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("BlockNode does not support NSCoding")
    }

    /// Changes the width, optionally with a short settle animation.
    func setWidth(_ width: CGFloat, animated: Bool) {
        blockWidth = width
        if animated {
            let resize = SKAction.resize(toWidth: width, duration: 0.22)
            resize.timingMode = .easeOut
            body.run(resize)
        } else {
            body.size.width = width
        }
        layoutWindows()
    }

    private func layoutWindows() {
        windows.forEach { $0.removeFromParent() }
        windows.removeAll()
        let count = max(1, Int(blockWidth / 44))
        guard blockWidth >= 24 else { return }
        for index in 0..<count {
            let window = SKShapeNode(rectOf: CGSize(width: 10, height: 8), cornerRadius: 2.5)
            window.fillColor = UIColor.white.withAlphaComponent(0.55)
            window.strokeColor = .clear
            let x = -blockWidth / 2 + blockWidth * (CGFloat(index) + 0.5) / CGFloat(count)
            window.position = CGPoint(x: x, y: -1)
            window.zPosition = 1
            addChild(window)
            windows.append(window)
        }
    }

    /// Turns the block into falling debris. It no longer belongs to the tower afterwards.
    func becomeDebris(impulse: CGVector, spin: CGFloat) {
        let physics = SKPhysicsBody(rectangleOf: body.size)
        physics.categoryBitMask = 0
        physics.collisionBitMask = 0
        physics.contactTestBitMask = 0
        physics.allowsRotation = true
        physics.angularDamping = 0.2
        physicsBody = physics
        physics.velocity = impulse
        physics.angularVelocity = spin
        zPosition = SceneLayer.debris
        run(.sequence([.wait(forDuration: 1.2), .fadeOut(withDuration: 0.6), .removeFromParent()]))
    }

    /// Sparkle ring for a perfect placement.
    func playPerfect(tint: UIColor) {
        let ring = SKShapeNode(rectOf: CGSize(width: blockWidth + 8, height: Self.height + 8), cornerRadius: 12)
        ring.strokeColor = tint
        ring.lineWidth = 3
        ring.glowWidth = 8
        ring.fillColor = .clear
        ring.zPosition = 2
        addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 1.25, duration: 0.4), .fadeOut(withDuration: 0.4)]),
            .removeFromParent()
        ]))

        let flash = SKAction.sequence([
            .run { [body] in body.color = .white; body.colorBlendFactor = 0.55 },
            .wait(forDuration: 0.08),
            .run { [body] in body.colorBlendFactor = 0 }
        ])
        run(flash)
    }

    /// Soft glow pulse when a cloud anchors the tower.
    func playAnchor() {
        let glow = SKSpriteNode(texture: TextureFactory.softCircle(diameter: 64))
        glow.size = CGSize(width: blockWidth * 1.6, height: Self.height * 3)
        glow.color = .white
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.alpha = 0.8
        glow.zPosition = -1
        addChild(glow)
        glow.run(.sequence([.group([.scale(to: 1.4, duration: 0.5), .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
    }
}
