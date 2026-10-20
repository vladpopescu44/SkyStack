import SpriteKit

/// One tower floor: a 9-slice sprite of the generated block art with real window sprites on top.
@MainActor
final class BlockNode: SKNode {
    static let height = CGFloat(GameBalance.blockHeight)

    let body: SKSpriteNode
    let textureName: String
    private let seed: Int
    private var windows: [SKSpriteNode] = []
    private(set) var blockWidth: CGFloat
    /// Position in world coordinates, kept so the tower can re-pivot around its top.
    var worldCenter: CGPoint = .zero

    init(width: CGFloat, textureName: String, seed: Int = 0) {
        self.textureName = textureName
        self.seed = seed
        blockWidth = width
        body = SKSpriteNode(texture: TextureFactory.art(textureName))
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

    /// Lit and glass windows, deterministic per floor so a block never flickers between looks.
    private func layoutWindows() {
        windows.forEach { $0.removeFromParent() }
        windows.removeAll()
        guard blockWidth >= 22 else { return }
        let count = max(1, Int(blockWidth / 30))
        var state = UInt64(truncatingIfNeeded: seed &* 2654435761 &+ 97)
        for index in 0..<count {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let lit = (state >> 33) % 3 != 0
            let window = SKSpriteNode(texture: TextureFactory.art(lit ? "window-lit" : "window-glass"))
            window.size = CGSize(width: 10, height: 13)
            let x = -blockWidth / 2 + blockWidth * (CGFloat(index) + 0.5) / CGFloat(count)
            window.position = CGPoint(x: x, y: 1)
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

    /// Sparkle ring and flash for a perfect placement.
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
