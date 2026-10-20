import SpriteKit

/// Receives gameplay updates from `TowerScene` on the main actor.
@MainActor
protocol TowerSceneDelegate: AnyObject {
    func scene(_ scene: TowerScene, didUpdate hud: GameHUDState)
    func scene(_ scene: TowerScene, didRegister event: GameEvent)
    func scene(_ scene: TowerScene, didFinishWith summary: RunSummary)
}

/// The SpriteKit scene for one build: a block swings above the tower, a tap drops it.
/// Gameplay rules live in `RunSession`; this class handles rendering, physics and input.
@MainActor
final class TowerScene: SKScene {
    weak var gameDelegate: TowerSceneDelegate?

    private(set) var session: RunSession
    private(set) var isRunning = false
    /// Whether a tap on the playfield drops the block (off when the drop button scheme is active).
    var acceptsTouchDrops: Bool

    private let loadout: BuilderLoadout
    private let world = SKNode()
    /// Holds the placed blocks and pillar. Its origin sits at the tower's top so the lean pivots there.
    private let tower = SKNode()
    private let cameraNode = SKCameraNode()
    private var blocks: [BlockNode] = []
    private var pillar: SKNode?
    private var movingBlock: BlockNode?
    private var movingDirection: CGFloat = 1
    private var builder: BuilderNode
    private var cloudNode: SKSpriteNode?
    private var lanternGuide: SKShapeNode?

    private var sky: SceneryBuilder.Sky?
    private var cloudLayer: SceneryBuilder.CloudLayer?
    private var starsEmitter: SKEmitterNode?
    private var rain: SKEmitterNode?
    private var windStreaks: SKEmitterNode?
    private var flash: SKSpriteNode?

    private var lastUpdateTime: TimeInterval?
    private var hudAccumulator: TimeInterval = 0
    private var hasFinished = false
    private var isSuspended = false
    private var lastSize: CGSize = .zero
    private var cameraY: CGFloat = 0
    private var leanAngle: CGFloat = 0
    /// Scene time of the last drop, used to ignore duplicate touches.
    private var lastDropTime: TimeInterval = 0
    private var currentTime: TimeInterval = 0

    private static let hudInterval: TimeInterval = 0.1
    /// Visual tilt at full lean, in radians.
    private static let maxTilt: CGFloat = 0.09
    private static let edgeMargin: CGFloat = 6
    /// Placed blocks kept in the scene; older ones are far below the camera.
    private static let visibleBlockLimit = 40

    init(size: CGSize, loadout: BuilderLoadout, acceptsTouchDrops: Bool) {
        self.loadout = loadout
        self.acceptsTouchDrops = acceptsTouchDrops
        session = RunSession(loadout: loadout, playfieldWidth: Double(size.width))
        builder = BuilderNode(skin: loadout.skin)
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("TowerScene does not support NSCoding")
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.30, green: 0.62, blue: 0.98, alpha: 1)
        physicsWorld.gravity = CGVector(dx: 0, dy: -7)
        view.ignoresSiblingOrder = true

        if cameraNode.parent == nil {
            addChild(cameraNode)
            camera = cameraNode
        }
        if world.parent == nil {
            addChild(world)
            tower.zPosition = SceneLayer.tower
            world.addChild(tower)
        }
        rebuildScenery(for: view.bounds.size == .zero ? size : view.bounds.size)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size != lastSize, size.width > 0, size.height > 0 else { return }
        rebuildScenery(for: size)
    }

    private func rebuildScenery(for newSize: CGSize) {
        lastSize = newSize
        [sky?.container, cloudLayer?.container, starsEmitter, rain, windStreaks, flash].forEach { $0?.removeFromParent() }

        let sky = SceneryBuilder.Sky(size: newSize)
        cameraNode.addChild(sky.container)
        self.sky = sky

        let clouds = SceneryBuilder.CloudLayer(size: newSize, count: 9)
        cameraNode.addChild(clouds.container)
        cloudLayer = clouds

        let stars = SceneryBuilder.makeStars(size: newSize)
        cameraNode.addChild(stars)
        starsEmitter = stars

        let rain = SceneryBuilder.makeRain(size: newSize)
        cameraNode.addChild(rain)
        self.rain = rain

        let wind = SceneryBuilder.makeWindStreaks(size: newSize)
        cameraNode.addChild(wind)
        windStreaks = wind

        let flash = SKSpriteNode(color: .white, size: CGSize(width: newSize.width + 4, height: newSize.height + 4))
        flash.alpha = 0
        flash.zPosition = SceneLayer.flash
        cameraNode.addChild(flash)
        self.flash = flash

        // Keep the playfield centred when the view is wider than the session's playfield (iPad rotation).
        world.position.x = (newSize.width - CGFloat(session.playfieldWidth)) / 2
        if blocks.isEmpty {
            buildBase()
        }
        cameraY = targetCameraY
        cameraNode.position = CGPoint(x: newSize.width / 2, y: cameraY)
        updateAltitudeVisuals()
        setStorm(session.isStorm, animated: false)
        if session.wind.isGusting {
            setWindStreaks(active: true)
        }
    }

    private func buildBase() {
        let width = CGFloat(session.baseWidth)
        let center = CGPoint(x: CGFloat(session.playfieldWidth) / 2, y: BlockNode.height / 2)

        let pillar = SceneryBuilder.makePillar(width: width * 0.86, color: loadout.skin.secondary)
        tower.addChild(pillar)
        self.pillar = pillar

        let base = BlockNode(width: width, color: loadout.skin.secondary, textureKey: "\(loadout.skin.rawValue)-base")
        base.worldCenter = center
        tower.addChild(base)
        blocks.append(base)
        repositionTower()

        // The builder waits on the base until the first block arrives.
        attachBuilder(to: base)
    }

    private func clearTower() {
        blocks.forEach { $0.removeFromParent() }
        blocks.removeAll()
        pillar?.removeFromParent()
        pillar = nil
        movingBlock?.removeFromParent()
        movingBlock = nil
        cloudNode?.removeFromParent()
        cloudNode = nil
        builder.removeFromParent()
    }

    // MARK: - Geometry

    private var playfieldWidth: CGFloat { CGFloat(session.playfieldWidth) }
    /// Top surface of the tower in world coordinates. The base counts as one block.
    private var topSurfaceY: CGFloat { CGFloat(session.floor + 1) * BlockNode.height }
    private var movingY: CGFloat { topSurfaceY + BlockNode.height / 2 }
    /// Keeps the moving block around 58% of the screen height.
    private var targetCameraY: CGFloat { movingY - size.height * 0.08 }

    private func minMovingX(for width: CGFloat) -> CGFloat { width / 2 + Self.edgeMargin }
    private func maxMovingX(for width: CGFloat) -> CGFloat { max(minMovingX(for: width), playfieldWidth - width / 2 - Self.edgeMargin) }

    /// Moves the tower's origin to its current top and re-expresses every block relative to it.
    private func repositionTower() {
        tower.position = CGPoint(x: playfieldWidth / 2, y: topSurfaceY)
        for block in blocks {
            block.position = CGPoint(x: block.worldCenter.x - tower.position.x, y: block.worldCenter.y - tower.position.y)
        }
        pillar?.position = CGPoint(x: 0, y: -tower.position.y)
    }

    private func attachBuilder(to block: BlockNode) {
        builder.removeFromParent()
        builder.removeAllActions()
        builder.physicsBody = nil
        builder.zRotation = 0
        builder.alpha = 1
        builder.setScale(1)
        builder.position = CGPoint(x: 0, y: BlockNode.height / 2)
        block.addChild(builder)
    }

    // MARK: - Run control

    /// Starts the build. Before this the scene idles with the base and the builder in place.
    func startRun() {
        guard !isRunning, !session.isOver else { return }
        if abs(playfieldWidth - size.width) > 1 {
            // The view ended up a different width than the scene was created with; rebuild the rules for it.
            session = RunSession(loadout: loadout, playfieldWidth: Double(size.width))
            clearTower()
            world.position.x = 0
            buildBase()
        }
        isRunning = true
        hasFinished = false
        lastUpdateTime = nil
        spawnMovingBlock()
        publishHUD()
    }

    /// Freezes or resumes the simulation, physics and actions. Idempotent.
    func setSuspended(_ suspended: Bool) {
        isSuspended = suspended
        isPaused = suspended
        physicsWorld.speed = suspended ? 0 : 1
        if !suspended {
            // Forget the stale timestamp so the first frame after resuming is a small step.
            lastUpdateTime = nil
        }
    }

    // MARK: - Frame update

    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdateTime = currentTime }
        self.currentTime = currentTime
        guard let last = lastUpdateTime else { return }
        // Clamp so a pause or hitch never produces a giant simulation step.
        let dt = min(max(currentTime - last, 0), 1.0 / 20.0)
        guard dt > 0, !isSuspended else { return }

        cloudLayer?.update(dt: dt, cameraY: cameraY)
        guard isRunning, !session.isOver else { return }

        let tick = session.advance(by: dt)
        if tick.windWarningStarted {
            gameDelegate?.scene(self, didRegister: .windWarning(session.wind.direction))
        }
        if tick.gustStarted {
            setWindStreaks(active: true)
            gameDelegate?.scene(self, didRegister: .gustStarted)
        }
        if tick.gustEnded {
            setWindStreaks(active: false)
        }

        moveBlock(dt: dt)
        syncCloud()
        syncLanternGuide()
        updateCamera(dt: dt)
        updateLean(dt: dt)

        hudAccumulator += dt
        if hudAccumulator >= Self.hudInterval {
            hudAccumulator = 0
            publishHUD()
        }
    }

    private func moveBlock(dt: TimeInterval) {
        guard let block = movingBlock else { return }
        let speed = CGFloat(session.blockSpeed)
        // Wind never fully overpowers the block, otherwise it could pin against an edge.
        let push = min(max(CGFloat(session.windPush), -speed * 0.6), speed * 0.6)
        var x = block.position.x + (movingDirection * speed + push) * CGFloat(dt)
        let lower = minMovingX(for: block.blockWidth)
        let upper = maxMovingX(for: block.blockWidth)
        if x <= lower {
            x = lower
            movingDirection = 1
        } else if x >= upper {
            x = upper
            movingDirection = -1
        }
        block.position.x = x
        builder.setLean(movingDirection * 0.5 + push / max(speed, 1))
    }

    private func updateCamera(dt: TimeInterval) {
        cameraY += (targetCameraY - cameraY) * min(1, CGFloat(dt) * 6)
        cameraNode.position = CGPoint(x: size.width / 2, y: cameraY)
        updateAltitudeVisuals()
    }

    private func updateAltitudeVisuals() {
        let altitude = min(1, CGFloat(session.floor) / 70)
        sky?.setAltitude(altitude)
        starsEmitter?.particleBirthRate = 30 * altitude
    }

    private func updateLean(dt: TimeInterval) {
        let target = -CGFloat(session.normalizedLean) * Self.maxTilt
        leanAngle += (target - leanAngle) * min(1, CGFloat(dt) * 4)
        tower.zRotation = leanAngle
    }

    // MARK: - Signature mechanics: visuals

    /// Cloud anchors: keep the cloud sprite in sync with the session's cloud.
    private func syncCloud() {
        if let cloud = session.cloud {
            if cloudNode == nil {
                let node = SKSpriteNode(texture: TextureFactory.cloud())
                node.size = CGSize(width: CGFloat(cloud.width) * 1.2, height: CGFloat(cloud.width) * 0.55)
                node.alpha = 0
                node.zPosition = SceneLayer.cloudAnchor
                node.run(.fadeAlpha(to: 0.92, duration: 0.4))
                let bob = SKAction.sequence([.moveBy(x: 0, y: 4, duration: 0.9), .moveBy(x: 0, y: -4, duration: 0.9)])
                bob.timingMode = .easeInEaseOut
                node.run(.repeatForever(bob))
                world.addChild(node)
                cloudNode = node
            }
            cloudNode?.position.x = CGFloat(cloud.centerX)
            cloudNode?.position.y = movingY - 2 + (cloudNode?.position.y ?? 0).truncatingRemainder(dividingBy: 1)
        } else if let node = cloudNode {
            cloudNode = nil
            node.removeAllActions()
            node.run(.sequence([.group([.fadeOut(withDuration: 0.35), .scale(to: 1.3, duration: 0.35)]), .removeFromParent()]))
        }
    }

    /// Sky Lantern: a guide line shows where the next blocks will land automatically.
    private func syncLanternGuide() {
        if session.isLanternActive {
            if lanternGuide == nil {
                let path = CGMutablePath()
                path.move(to: CGPoint(x: 0, y: -BlockNode.height * 0.5))
                path.addLine(to: CGPoint(x: 0, y: BlockNode.height * 2.5))
                let guide = SKShapeNode(path: path)
                guide.strokeColor = UIColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 0.9)
                guide.lineWidth = 2
                guide.glowWidth = 6
                guide.zPosition = SceneLayer.effects
                world.addChild(guide)
                lanternGuide = guide
            }
            lanternGuide?.position = CGPoint(x: CGFloat(session.topCenterX), y: topSurfaceY)
        } else if let guide = lanternGuide {
            lanternGuide = nil
            guide.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
            builder.setLantern(false)
        }
    }

    /// Wind gusts: streaks blow across the screen in the gust's direction.
    private func setWindStreaks(active: Bool) {
        guard let windStreaks else { return }
        if active {
            let direction = session.wind.direction
            windStreaks.emissionAngle = direction == .right ? 0 : .pi
            windStreaks.position = CGPoint(x: direction == .right ? -size.width / 2 - 60 : size.width / 2 + 60, y: 0)
            windStreaks.particleBirthRate = 26 * CGFloat(session.wind.strength)
        } else {
            windStreaks.particleBirthRate = 0
        }
    }

    /// Storm bands: darker sky, rain and a lightning flash when one begins.
    private func setStorm(_ active: Bool, animated: Bool = true) {
        sky?.setStorm(active)
        rain?.particleBirthRate = active ? 150 : 0
        guard active, animated, let flash else { return }
        flash.removeAllActions()
        flash.run(.sequence([.fadeAlpha(to: 0.75, duration: 0.05), .fadeAlpha(to: 0, duration: 0.4)]))
        shakeWorld(intensity: 5)
    }

    // MARK: - Spawning and placement

    private func spawnMovingBlock() {
        let width = CGFloat(session.topWidth)
        let floorIndex = session.currentFloor
        let paletteIndex = floorIndex % loadout.skin.blockPalette.count
        let block = BlockNode(
            width: width,
            color: loadout.skin.blockColor(forFloor: floorIndex),
            textureKey: "\(loadout.skin.rawValue)-\(paletteIndex)"
        )
        let fromLeft = floorIndex % 2 == 1
        movingDirection = fromLeft ? 1 : -1
        block.position = CGPoint(x: fromLeft ? minMovingX(for: width) : maxMovingX(for: width), y: movingY)
        block.zPosition = SceneLayer.movingBlock
        block.alpha = 0
        block.run(.fadeIn(withDuration: 0.12))
        world.addChild(block)
        movingBlock = block

        attachBuilder(to: block)
        builder.hop()
        builder.setLantern(session.isLanternActive)
    }

    /// Drops the moving block where it is. Called by taps or the drop button.
    func dropBlock() {
        // A short debounce swallows duplicate touches from a single tap.
        guard isRunning, !isSuspended, let block = movingBlock,
              currentTime - lastDropTime > 0.12 else { return }
        // Capture the row before the session advances its floor counter.
        let rowY = movingY
        guard let result = session.place(blockCenterX: Double(block.position.x)) else { return }
        lastDropTime = currentTime
        movingBlock = nil
        handle(result, block: block, rowY: rowY)
    }

    private func handle(_ result: PlacementResult, block: BlockNode, rowY: CGFloat) {
        block.removeAllActions()
        block.alpha = 1

        if result.kind == .missed {
            // The whole block tumbles past the tower.
            block.position.x += CGFloat(result.windSlip)
            let side: CGFloat = result.finalOffset < 0 ? -1 : 1
            detachBuilderToWorld()
            builder.fall(direction: side)
            block.becomeDebris(impulse: CGVector(dx: side * 50, dy: -30), spin: -side * 2.5)
            shakeWorld(intensity: 8)
            gameDelegate?.scene(self, didRegister: .missed)
            finishRun(after: 1.2)
            return
        }

        // Keep the part that stayed on the tower.
        let previousWidth = block.blockWidth
        let keptWidth = previousWidth - CGFloat(result.trimmedWidth)
        let keptCenter = CGPoint(x: CGFloat(result.centerX), y: rowY)
        block.removeFromParent()
        block.setWidth(max(keptWidth, 1), animated: false)
        block.worldCenter = keptCenter
        block.zPosition = 0
        blocks.append(block)
        tower.addChild(block)
        repositionTower()
        if result.windSlip != 0 {
            // Visualise the slip: start where the player dropped it and slide into place.
            block.position.x -= CGFloat(result.windSlip)
            let slide = SKAction.moveBy(x: CGFloat(result.windSlip), y: 0, duration: 0.12)
            slide.timingMode = .easeOut
            block.run(slide)
        }

        // The piece that broke off.
        if result.trimmedWidth > 0.5, let side = result.trimmedSide {
            let piece = BlockNode(width: CGFloat(result.trimmedWidth), color: block.color, textureKey: "\(loadout.skin.rawValue)-\(result.floor % loadout.skin.blockPalette.count)")
            let offset = CGFloat(side.sign) * (keptWidth / 2 + CGFloat(result.trimmedWidth) / 2)
            piece.position = CGPoint(x: keptCenter.x + offset, y: rowY)
            world.addChild(piece)
            piece.becomeDebris(impulse: CGVector(dx: CGFloat(side.sign) * 70, dy: 40), spin: -CGFloat(side.sign) * 3)
        }

        // Feedback for the mechanics.
        if result.isPerfect {
            block.playPerfect(tint: loadout.skin.glow.uiColor)
            builder.celebrate()
            let streak = session.perfectStreak
            floatLabel(streak > 1 ? "PERFECT x\(streak)" : "PERFECT", at: keptCenter, color: UIColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1))
        }
        if result.isAnchored {
            block.setWidth(CGFloat(result.width), animated: true)
            block.playAnchor()
            floatLabel("ANCHORED", at: CGPoint(x: keptCenter.x, y: keptCenter.y + 26), color: .white)
            gameDelegate?.scene(self, didRegister: .anchored)
        }
        if result.lanternLit {
            floatLabel("LANTERN LIT", at: CGPoint(x: keptCenter.x, y: keptCenter.y + 52), color: UIColor(red: 1.0, green: 0.9, blue: 0.5, alpha: 1))
            gameDelegate?.scene(self, didRegister: .lanternLit)
        }
        if result.stormStarted {
            setStorm(true)
            gameDelegate?.scene(self, didRegister: .stormStarted)
        }
        if result.stormEnded {
            setStorm(false)
            gameDelegate?.scene(self, didRegister: .stormEnded)
        }
        gameDelegate?.scene(self, didRegister: .placed(perfect: result.isPerfect))

        if result.kind == .toppled {
            topple(direction: session.lean < 0 ? -1 : 1)
            gameDelegate?.scene(self, didRegister: .toppled)
            finishRun(after: 1.4)
            return
        }

        cullOldBlocks()
        spawnMovingBlock()
        publishHUD()
    }

    private func detachBuilderToWorld() {
        guard let parent = builder.parent else { return }
        let worldPosition = parent.convert(builder.position, to: world)
        builder.removeFromParent()
        builder.position = worldPosition
        builder.zPosition = SceneLayer.builder
        world.addChild(builder)
    }

    /// Tower lean: the tower crumbles sideways when the lean capacity is exceeded.
    private func topple(direction: CGFloat) {
        detachBuilderToWorld()
        builder.fall(direction: direction)

        let falling = blocks.dropFirst().suffix(16)
        let count = max(1, falling.count)
        for (index, block) in falling.enumerated() {
            let worldPosition = tower.convert(block.position, to: world)
            block.removeFromParent()
            block.position = worldPosition
            block.zRotation = tower.zRotation
            world.addChild(block)
            let heightFactor = CGFloat(index) / CGFloat(count)
            block.becomeDebris(
                impulse: CGVector(dx: direction * (40 + 200 * heightFactor), dy: 20 + 60 * heightFactor),
                spin: -direction * (1 + 3 * heightFactor)
            )
        }
        blocks.removeAll { $0.parent !== tower }
        shakeWorld(intensity: 14)
    }

    private func cullOldBlocks() {
        guard blocks.count > Self.visibleBlockLimit else { return }
        // Keep the base so the pillar always has a block on top of it.
        let removable = blocks.dropFirst().prefix(blocks.count - Self.visibleBlockLimit)
        removable.forEach { $0.removeFromParent() }
        blocks.removeAll { $0.parent == nil }
    }

    private func floatLabel(_ text: String, at point: CGPoint, color: UIColor) {
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 18
        label.fontColor = color
        label.position = CGPoint(x: point.x, y: point.y + 28)
        label.zPosition = SceneLayer.effects
        label.setScale(0.6)
        world.addChild(label)
        let pop = SKAction.scale(to: 1, duration: 0.15)
        pop.timingMode = .easeOut
        label.run(.sequence([
            pop,
            .group([.moveBy(x: 0, y: 36, duration: 0.75), .sequence([.wait(forDuration: 0.35), .fadeOut(withDuration: 0.4)])]),
            .removeFromParent()
        ]))
    }

    private func finishRun(after delay: TimeInterval) {
        guard !hasFinished else { return }
        hasFinished = true
        isRunning = false
        setWindStreaks(active: false)
        lanternGuide?.removeFromParent()
        lanternGuide = nil
        publishHUD()

        let summary = session.summary
        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in
                guard let self else { return }
                self.gameDelegate?.scene(self, didFinishWith: summary)
            }
        ]))
    }

    private func shakeWorld(intensity: CGFloat) {
        world.removeAction(forKey: "shake")
        let baseX = (size.width - playfieldWidth) / 2
        var actions: [SKAction] = []
        var amplitude = intensity
        for _ in 0..<5 {
            let dx = CGFloat.random(in: -amplitude...amplitude)
            let dy = CGFloat.random(in: -amplitude...amplitude)
            actions.append(.moveBy(x: dx, y: dy, duration: 0.03))
            actions.append(.moveBy(x: -dx, y: -dy, duration: 0.03))
            amplitude *= 0.6
        }
        actions.append(.move(to: CGPoint(x: baseX, y: 0), duration: 0.02))
        world.run(.sequence(actions), withKey: "shake")
    }

    private func publishHUD() {
        gameDelegate?.scene(self, didUpdate: GameHUDState(session: session))
    }

    // MARK: - Touch input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard acceptsTouchDrops else { return }
        dropBlock()
    }
}
