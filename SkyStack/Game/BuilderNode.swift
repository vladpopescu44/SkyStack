import SpriteKit

/// The little builder who rides on the moving block, drawn from vector shapes tinted by the skin.
@MainActor
final class BuilderNode: SKNode {
    private let body: SKShapeNode
    private let head: SKShapeNode
    private let hat: SKShapeNode
    private let brim: SKShapeNode
    private let goggles: SKShapeNode
    private let lantern: SKSpriteNode
    private let glowColor: UIColor

    init(skin: BuilderSkin) {
        let primary = skin.primary.uiColor
        let secondary = skin.secondary.uiColor
        glowColor = skin.glow.uiColor

        body = SKShapeNode(path: CGPath(roundedRect: CGRect(x: -9, y: 0, width: 18, height: 22), cornerWidth: 8, cornerHeight: 8, transform: nil))
        body.fillColor = primary
        body.strokeColor = secondary
        body.lineWidth = 2

        head = SKShapeNode(circleOfRadius: 8.5)
        head.position = CGPoint(x: 0, y: 28)
        head.fillColor = primary
        head.strokeColor = secondary
        head.lineWidth = 2

        hat = SKShapeNode(path: CGPath(roundedRect: CGRect(x: -9, y: 31, width: 18, height: 9), cornerWidth: 7, cornerHeight: 7, transform: nil))
        hat.fillColor = secondary
        hat.strokeColor = .clear

        brim = SKShapeNode(rectOf: CGSize(width: 22, height: 3), cornerRadius: 1.5)
        brim.position = CGPoint(x: 0, y: 32)
        brim.fillColor = secondary
        brim.strokeColor = .clear

        goggles = SKShapeNode(path: CGPath(roundedRect: CGRect(x: -6, y: -2.5, width: 12, height: 5), cornerWidth: 2.5, cornerHeight: 2.5, transform: nil))
        goggles.position = CGPoint(x: 0, y: 28)
        goggles.fillColor = glowColor
        goggles.strokeColor = .clear
        goggles.glowWidth = 1.5

        lantern = SKSpriteNode(texture: TextureFactory.softCircle(diameter: 64))
        lantern.size = CGSize(width: 70, height: 70)
        lantern.position = CGPoint(x: 0, y: 20)
        lantern.color = UIColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1)
        lantern.colorBlendFactor = 1
        lantern.blendMode = .add
        lantern.alpha = 0
        lantern.zPosition = -1

        super.init()

        addChild(lantern)
        addChild(body)
        addChild(head)
        addChild(hat)
        addChild(brim)
        addChild(goggles)
        zPosition = SceneLayer.builder
        runIdle()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("BuilderNode does not support NSCoding")
    }

    private func runIdle() {
        let up = SKAction.moveBy(x: 0, y: 2, duration: 0.7)
        up.timingMode = .easeInEaseOut
        head.run(.repeatForever(.sequence([up, up.reversed()])), withKey: "idle")
    }

    /// Leans against the direction of travel, `amount` in `-1...1`.
    func setLean(_ amount: CGFloat) {
        zRotation = -min(max(amount, -1), 1) * 0.18
    }

    /// Little squash-and-stretch hop when landing on a new block.
    func hop() {
        removeAction(forKey: "hop")
        let squash = SKAction.scaleX(to: 1.15, y: 0.85, duration: 0.08)
        let stretch = SKAction.scaleX(to: 0.92, y: 1.1, duration: 0.1)
        let settle = SKAction.scale(to: 1, duration: 0.12)
        settle.timingMode = .easeOut
        run(.sequence([squash, stretch, settle]), withKey: "hop")
    }

    /// Shows or hides the lantern glow that marks auto-centred floors.
    func setLantern(_ visible: Bool) {
        lantern.removeAction(forKey: "lantern")
        if visible {
            lantern.alpha = 0.9
            let pulse = SKAction.sequence([.scale(to: 1.2, duration: 0.5), .scale(to: 0.9, duration: 0.5)])
            lantern.run(.repeatForever(pulse), withKey: "lantern")
        } else {
            lantern.run(.fadeOut(withDuration: 0.3), withKey: "lantern")
        }
    }

    /// Celebration burst for perfects and anchors.
    func celebrate() {
        let burst = SKEmitterNode()
        burst.particleTexture = TextureFactory.softCircle(diameter: 32)
        burst.numParticlesToEmit = 14
        burst.particleBirthRate = 200
        burst.particleLifetime = 0.6
        burst.particleSpeed = 120
        burst.particleSpeedRange = 60
        burst.emissionAngle = .pi / 2
        burst.emissionAngleRange = .pi
        burst.yAcceleration = -200
        burst.particleScale = 0.35
        burst.particleScaleSpeed = -0.5
        burst.particleAlphaSpeed = -1.4
        burst.particleColor = glowColor
        burst.particleColorBlendFactor = 1
        burst.particleBlendMode = .add
        burst.position = CGPoint(x: 0, y: 30)
        burst.zPosition = 2
        addChild(burst)
        burst.run(.sequence([.wait(forDuration: 1), .removeFromParent()]))
    }

    /// Tumbles off when the tower falls.
    func fall(direction: CGFloat) {
        removeAllActions()
        let physics = SKPhysicsBody(circleOfRadius: 12)
        physics.categoryBitMask = 0
        physics.collisionBitMask = 0
        physics.contactTestBitMask = 0
        physicsBody = physics
        physics.velocity = CGVector(dx: direction * 120, dy: 260)
        physics.angularVelocity = -direction * 6
        run(.sequence([.wait(forDuration: 1.4), .fadeOut(withDuration: 0.4), .removeFromParent()]))
    }
}
