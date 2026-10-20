import SpriteKit

/// The builder who rides on the moving block, drawn with the generated character art.
@MainActor
final class BuilderNode: SKNode {
    private let sprite: SKSpriteNode
    private let lantern: SKSpriteNode
    private let lanternGlow: SKSpriteNode
    private let glowColor: UIColor

    init(skin: BuilderSkin) {
        glowColor = skin.glow.uiColor

        sprite = SKSpriteNode(texture: TextureFactory.art(skin.portraitAsset))
        sprite.size = CGSize(width: 40, height: 47)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.05)

        lanternGlow = SKSpriteNode(texture: TextureFactory.softCircle(diameter: 64))
        lanternGlow.size = CGSize(width: 80, height: 80)
        lanternGlow.position = CGPoint(x: 0, y: 64)
        lanternGlow.color = UIColor(red: 1.0, green: 0.8, blue: 0.4, alpha: 1)
        lanternGlow.colorBlendFactor = 1
        lanternGlow.blendMode = .add
        lanternGlow.alpha = 0

        lantern = SKSpriteNode(texture: TextureFactory.art("lantern"))
        lantern.size = CGSize(width: 22, height: 29)
        lantern.position = CGPoint(x: 0, y: 64)
        lantern.alpha = 0

        super.init()

        addChild(lanternGlow)
        addChild(sprite)
        addChild(lantern)
        zPosition = SceneLayer.builder
        runIdle()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("BuilderNode does not support NSCoding")
    }

    private func runIdle() {
        let up = SKAction.scaleY(to: 1.03, duration: 0.6)
        up.timingMode = .easeInEaseOut
        let down = SKAction.scaleY(to: 0.98, duration: 0.6)
        down.timingMode = .easeInEaseOut
        sprite.run(.repeatForever(.sequence([up, down])), withKey: "idle")
    }

    /// Leans against the direction of travel, `amount` in `-1...1`.
    func setLean(_ amount: CGFloat) {
        zRotation = -min(max(amount, -1), 1) * 0.14
    }

    /// Squash-and-stretch hop when landing on a new block.
    func hop() {
        removeAction(forKey: "hop")
        let squash = SKAction.scaleX(to: 1.15, y: 0.85, duration: 0.08)
        let stretch = SKAction.scaleX(to: 0.92, y: 1.1, duration: 0.1)
        let settle = SKAction.scale(to: 1, duration: 0.12)
        settle.timingMode = .easeOut
        run(.sequence([squash, stretch, settle]), withKey: "hop")
    }

    /// Shows or hides the Sky Lantern the builder carries while blocks auto-centre.
    func setLantern(_ visible: Bool) {
        lantern.removeAction(forKey: "lantern")
        lanternGlow.removeAction(forKey: "lantern")
        if visible {
            lantern.alpha = 1
            lanternGlow.alpha = 0.9
            let bob = SKAction.sequence([.moveBy(x: 0, y: 4, duration: 0.6), .moveBy(x: 0, y: -4, duration: 0.6)])
            lantern.run(.repeatForever(bob), withKey: "lantern")
            lanternGlow.run(.repeatForever(.sequence([.scale(to: 1.2, duration: 0.6), .scale(to: 0.9, duration: 0.6)])), withKey: "lantern")
        } else {
            lantern.run(.fadeOut(withDuration: 0.3), withKey: "lantern")
            lanternGlow.run(.fadeOut(withDuration: 0.3), withKey: "lantern")
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
        physics.velocity = CGVector(dx: direction * 90, dy: 240)
        physics.angularVelocity = -direction * 5
        run(.sequence([.wait(forDuration: 0.9), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }
}
