import SpriteKit

/// Builds the scenery around the tower from the generated art: painted skies, parallax clouds,
/// weather emitters and the building the tower stands on.
@MainActor
enum SceneryBuilder {
    /// Day, dusk and night skies that cross-fade with altitude, plus a storm sky on top.
    final class Sky {
        let container = SKNode()
        private let day: SKSpriteNode
        private let dusk: SKSpriteNode
        private let night: SKSpriteNode
        private let storm: SKSpriteNode

        init(size: CGSize) {
            day = SKSpriteNode(texture: TextureFactory.art("sky-day"))
            dusk = SKSpriteNode(texture: TextureFactory.art("sky-dusk"))
            night = SKSpriteNode(texture: TextureFactory.art("sky-night"))
            storm = SKSpriteNode(texture: TextureFactory.art("sky-storm"))
            for (index, node) in [day, dusk, night, storm].enumerated() {
                node.zPosition = index == 3 ? SceneLayer.stormTint : SceneLayer.sky + CGFloat(index) * 0.1
                container.addChild(node)
            }
            dusk.alpha = 0
            night.alpha = 0
            storm.alpha = 0
            resize(to: size)
        }

        /// Aspect-fills every sky sprite to the screen.
        func resize(to size: CGSize) {
            for node in [day, dusk, night, storm] {
                let texture = node.texture?.size() ?? CGSize(width: 260, height: 563)
                let scale = max((size.width + 4) / texture.width, (size.height + 4) / texture.height)
                node.size = CGSize(width: texture.width * scale, height: texture.height * scale)
            }
        }

        /// Fades from day to dusk to night as the tower climbs.
        func setFloor(_ floor: Int) {
            dusk.alpha = min(max((CGFloat(floor) - 12) / 16, 0), 1)
            night.alpha = min(max((CGFloat(floor) - 38) / 18, 0), 1)
        }

        func setStorm(_ active: Bool) {
            storm.run(.fadeAlpha(to: active ? 0.92 : 0, duration: 0.8), withKey: "storm")
        }
    }

    /// Decorative clouds that scroll slower than the camera for depth.
    final class CloudLayer {
        let container = SKNode()
        private var sprites: [(node: SKSpriteNode, speed: CGFloat, depth: CGFloat, baseY: CGFloat)] = []
        private var size: CGSize

        init(size: CGSize, count: Int) {
            self.size = size
            container.zPosition = SceneLayer.farClouds
            var generator = SeededGenerator(seed: 77)
            let names = ["cloud-a", "cloud-b", "cloud-c"]
            for index in 0..<count {
                let node = SKSpriteNode(texture: TextureFactory.art(names[index % names.count]))
                let width = CGFloat.random(in: 90...190, using: &generator)
                node.size = CGSize(width: width, height: width * 0.47)
                // Scenery clouds stay faint so the gameplay cloud reads clearly.
                node.alpha = CGFloat.random(in: 0.35...0.6, using: &generator)
                let baseY = CGFloat.random(in: -size.height * 0.6...size.height * 0.6, using: &generator)
                node.position = CGPoint(x: CGFloat.random(in: -size.width * 0.6...size.width * 0.6, using: &generator), y: baseY)
                container.addChild(node)
                sprites.append((node, CGFloat.random(in: 6...18, using: &generator), CGFloat.random(in: 0.15...0.45, using: &generator), baseY))
            }
        }

        func resize(to size: CGSize) {
            self.size = size
        }

        /// Scrolls clouds sideways and parallaxes them against the camera height.
        func update(dt: TimeInterval, cameraY: CGFloat, dimmed: Bool) {
            let halfWidth = size.width / 2 + 160
            let halfHeight = size.height / 2 + 80
            let span = halfHeight * 2
            for entry in sprites {
                var x = entry.node.position.x + entry.speed * CGFloat(dt)
                if x > halfWidth { x = -halfWidth }
                entry.node.position.x = x
                var y = (entry.baseY - cameraY * entry.depth).truncatingRemainder(dividingBy: span)
                if y > halfHeight { y -= span }
                if y < -halfHeight { y += span }
                entry.node.position.y = y
                entry.node.colorBlendFactor = dimmed ? 0.55 : 0
                entry.node.color = UIColor(red: 0.3, green: 0.34, blue: 0.48, alpha: 1)
            }
        }
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
        wind.particleAlpha = 0.55
        wind.particleAlphaRange = 0.2
        wind.particleAlphaSpeed = -0.4
        wind.particleColor = .white
        wind.particleColorBlendFactor = 1
        wind.zPosition = SceneLayer.weather
        return wind
    }

    /// The painted building the tower stands on, with a shelf of clouds around its roof.
    static func makePillar(width: CGFloat) -> SKNode {
        let container = SKNode()
        container.zPosition = SceneLayer.pillar

        let building = SKSpriteNode(texture: TextureFactory.art("tower-building"))
        building.anchorPoint = CGPoint(x: 0.5, y: 1)
        building.size = CGSize(width: width, height: width * 3)
        building.position = .zero
        container.addChild(building)

        let names = ["cloud-a", "cloud-c", "cloud-b"]
        for (index, (dx, scale)) in [(-0.85, 0.9), (0.0, 1.15), (0.9, 0.85)].enumerated() {
            let cloud = SKSpriteNode(texture: TextureFactory.art(names[index]))
            cloud.size = CGSize(width: 150 * scale, height: 70 * scale)
            cloud.position = CGPoint(x: CGFloat(dx) * width * 0.62, y: -30)
            cloud.zPosition = 1
            container.addChild(cloud)
        }
        return container
    }
}
