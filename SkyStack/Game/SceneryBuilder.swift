import SpriteKit

/// Builds the scenery around the tower: sky layers, parallax clouds, weather and the pillar.
/// Everything is drawn procedurally.
@MainActor
enum SceneryBuilder {
    /// Two gradient layers that cross-fade with altitude, plus a storm tint.
    final class Sky {
        let container = SKNode()
        private let day: SKSpriteNode
        private let night: SKSpriteNode
        private let storm: SKSpriteNode

        init(size: CGSize) {
            day = SKSpriteNode(texture: TextureFactory.verticalGradient(
                size: CGSize(width: 8, height: 256),
                colors: [
                    UIColor(red: 0.30, green: 0.62, blue: 0.98, alpha: 1),
                    UIColor(red: 0.55, green: 0.80, blue: 1.0, alpha: 1),
                    UIColor(red: 0.95, green: 0.82, blue: 0.72, alpha: 1)
                ],
                key: "day"
            ))
            night = SKSpriteNode(texture: TextureFactory.verticalGradient(
                size: CGSize(width: 8, height: 256),
                colors: [
                    UIColor(red: 0.03, green: 0.04, blue: 0.14, alpha: 1),
                    UIColor(red: 0.08, green: 0.12, blue: 0.32, alpha: 1),
                    UIColor(red: 0.22, green: 0.30, blue: 0.62, alpha: 1)
                ],
                key: "night"
            ))
            storm = SKSpriteNode(color: UIColor(red: 0.10, green: 0.12, blue: 0.22, alpha: 1), size: size)
            day.zPosition = SceneLayer.sky
            night.zPosition = SceneLayer.sky + 0.1
            storm.zPosition = SceneLayer.stormTint
            night.alpha = 0
            storm.alpha = 0
            container.addChild(day)
            container.addChild(night)
            container.addChild(storm)
            resize(to: size)
        }

        func resize(to size: CGSize) {
            let padded = CGSize(width: size.width + 4, height: size.height + 4)
            day.size = padded
            night.size = padded
            storm.size = padded
        }

        /// `altitude` in `0...1` fades the day sky into the upper atmosphere.
        func setAltitude(_ altitude: CGFloat) {
            night.alpha = min(max(altitude, 0), 1)
        }

        func setStorm(_ active: Bool) {
            storm.run(.fadeAlpha(to: active ? 0.45 : 0, duration: 0.8), withKey: "storm")
        }
    }

    /// Decorative clouds that scroll slower than the camera for depth.
    final class CloudLayer {
        let container = SKNode()
        private var sprites: [(node: SKSpriteNode, speed: CGFloat, depth: CGFloat)] = []
        private var size: CGSize

        init(size: CGSize, count: Int) {
            self.size = size
            container.zPosition = SceneLayer.farClouds
            var generator = SeededGenerator(seed: 77)
            for _ in 0..<count {
                let node = SKSpriteNode(texture: TextureFactory.cloud())
                let scale = CGFloat.random(in: 0.5...1.4, using: &generator)
                node.size = CGSize(width: 200 * scale, height: 100 * scale)
                node.alpha = CGFloat.random(in: 0.35...0.8, using: &generator)
                node.position = CGPoint(
                    x: CGFloat.random(in: -size.width * 0.6...size.width * 0.6, using: &generator),
                    y: CGFloat.random(in: -size.height * 0.6...size.height * 0.6, using: &generator)
                )
                container.addChild(node)
                sprites.append((node, CGFloat.random(in: 6...18, using: &generator), CGFloat.random(in: 0.15...0.45, using: &generator)))
            }
        }

        func resize(to size: CGSize) {
            self.size = size
        }

        /// Scrolls clouds sideways and parallaxes them against the camera height.
        func update(dt: TimeInterval, cameraY: CGFloat) {
            let halfWidth = size.width / 2 + 160
            let halfHeight = size.height / 2 + 80
            for entry in sprites {
                var x = entry.node.position.x + entry.speed * CGFloat(dt)
                if x > halfWidth { x = -halfWidth }
                entry.node.position.x = x
                // Vertical parallax: wrap within the visible band as the camera climbs.
                let raw = entry.node.userData?["baseY"] as? CGFloat ?? entry.node.position.y
                if entry.node.userData == nil {
                    entry.node.userData = ["baseY": raw]
                }
                var y = raw - cameraY * entry.depth
                let span = halfHeight * 2
                y = y.truncatingRemainder(dividingBy: span)
                if y > halfHeight { y -= span }
                if y < -halfHeight { y += span }
                entry.node.position.y = y
            }
        }
    }

    static func makeStars(size: CGSize) -> SKEmitterNode {
        let stars = SKEmitterNode()
        stars.particleTexture = TextureFactory.softCircle(diameter: 32)
        stars.particlePositionRange = CGVector(dx: size.width * 1.2, dy: size.height * 1.2)
        stars.particleBirthRate = 0
        stars.particleLifetime = 6
        stars.particleLifetimeRange = 3
        stars.particleScale = 0.08
        stars.particleScaleRange = 0.05
        stars.particleAlpha = 0
        stars.particleAlphaSpeed = 0.6
        stars.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 0.9, 0.9, 0], times: [0, 0.2, 0.8, 1])
        stars.particleColor = .white
        stars.particleColorBlendFactor = 1
        stars.zPosition = SceneLayer.stars
        return stars
    }

    static func makeRain(size: CGSize) -> SKEmitterNode {
        let rain = SKEmitterNode()
        rain.particleTexture = TextureFactory.streak()
        rain.position = CGPoint(x: 0, y: size.height / 2 + 40)
        rain.particlePositionRange = CGVector(dx: size.width * 1.4, dy: 0)
        rain.particleBirthRate = 0
        rain.particleLifetime = 1.4
        rain.particleSpeed = 620
        rain.particleSpeedRange = 120
        rain.emissionAngle = -.pi / 2 - 0.18
        rain.emissionAngleRange = 0.05
        rain.particleRotation = .pi / 2 + 0.18
        rain.particleScale = 0.45
        rain.particleScaleRange = 0.15
        rain.particleAlpha = 0.45
        rain.particleAlphaRange = 0.2
        rain.particleColor = UIColor(red: 0.75, green: 0.85, blue: 1.0, alpha: 1)
        rain.particleColorBlendFactor = 1
        rain.zPosition = SceneLayer.weather
        return rain
    }

    static func makeWindStreaks(size: CGSize) -> SKEmitterNode {
        let wind = SKEmitterNode()
        wind.particleTexture = TextureFactory.streak()
        wind.particlePositionRange = CGVector(dx: 0, dy: size.height * 1.1)
        wind.particleBirthRate = 0
        wind.particleLifetime = 1.1
        wind.particleSpeed = 520
        wind.particleSpeedRange = 160
        wind.emissionAngleRange = 0.05
        wind.particleScale = 0.9
        wind.particleScaleRange = 0.4
        wind.particleAlpha = 0.5
        wind.particleAlphaRange = 0.2
        wind.particleAlphaSpeed = -0.4
        wind.particleColor = .white
        wind.particleColorBlendFactor = 1
        wind.zPosition = SceneLayer.weather
        return wind
    }

    /// The tall pillar the tower stands on, reaching far below the base block.
    static func makePillar(width: CGFloat, color: RGB) -> SKNode {
        let container = SKNode()
        container.zPosition = SceneLayer.pillar

        let height: CGFloat = 2400
        let pillar = SKShapeNode(rect: CGRect(x: -width / 2, y: -height, width: width, height: height), cornerRadius: 10)
        pillar.fillColor = UIColor(red: 0.16, green: 0.20, blue: 0.36, alpha: 1)
        pillar.strokeColor = UIColor(red: 0.28, green: 0.34, blue: 0.55, alpha: 1)
        pillar.lineWidth = 2
        container.addChild(pillar)

        // A few lit windows so the pillar reads as a building.
        var generator = SeededGenerator(seed: 5)
        for row in 0..<28 {
            let y = -22 - CGFloat(row) * 44
            let columns = max(2, Int(width / 30))
            for column in 0..<columns where Bool.random(using: &generator) {
                let window = SKShapeNode(rectOf: CGSize(width: 8, height: 10), cornerRadius: 2)
                let x = -width / 2 + width * (CGFloat(column) + 0.5) / CGFloat(columns)
                window.position = CGPoint(x: x, y: y)
                window.fillColor = UIColor(red: 1.0, green: 0.85, blue: 0.5, alpha: CGFloat.random(in: 0.35...0.8, using: &generator))
                window.strokeColor = .clear
                container.addChild(window)
            }
        }

        // Cloud shelf around the base.
        for (dx, scale, alpha) in [(-0.9, 0.9, 0.85), (0.0, 1.2, 0.95), (0.95, 0.85, 0.8)] as [(CGFloat, CGFloat, CGFloat)] {
            let cloud = SKSpriteNode(texture: TextureFactory.cloud())
            cloud.size = CGSize(width: 150 * scale, height: 75 * scale)
            cloud.position = CGPoint(x: dx * width * 0.6, y: -28)
            cloud.alpha = alpha
            container.addChild(cloud)
        }

        return container
    }
}
