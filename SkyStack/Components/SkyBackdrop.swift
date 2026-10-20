import SwiftUI

/// Animated menu background: a deep night-sky gradient with drifting clouds and twinkling stars.
/// Drawn with `Canvas` inside a `TimelineView` so it costs no view updates.
struct SkyBackdrop: View {
    private struct Puff {
        let x: Double
        let y: Double
        let speed: Double
        let scale: Double
        let alpha: Double
    }

    private struct Star {
        let x: Double
        let y: Double
        let size: Double
        let phase: Double
    }

    private let puffs: [Puff]
    private let stars: [Star]

    init(cloudCount: Int = 7, starCount: Int = 40) {
        var generator = SeededGenerator(seed: 2026)
        puffs = (0..<cloudCount).map { _ in
            Puff(
                x: Double.random(in: 0...1, using: &generator),
                y: Double.random(in: 0.25...0.95, using: &generator),
                speed: Double.random(in: 0.012...0.03, using: &generator),
                scale: Double.random(in: 0.6...1.3, using: &generator),
                alpha: Double.random(in: 0.05...0.12, using: &generator)
            )
        }
        stars = (0..<starCount).map { _ in
            Star(
                x: Double.random(in: 0...1, using: &generator),
                y: Double.random(in: 0...0.6, using: &generator),
                size: Double.random(in: 1.2...2.8, using: &generator),
                phase: Double.random(in: 0...(.pi * 2), using: &generator)
            )
        }
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient

            // A soft horizon glow, like the last light under the clouds.
            RadialGradient(
                colors: [Theme.Colors.skyDeep.opacity(0.35), .clear],
                center: .bottom,
                startRadius: 0,
                endRadius: 560
            )

            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                Canvas { canvas, size in
                    for star in stars {
                        let twinkle = 0.55 + 0.45 * sin(time * 1.6 + star.phase)
                        let rect = CGRect(
                            x: size.width * star.x - star.size / 2,
                            y: size.height * star.y - star.size / 2,
                            width: star.size,
                            height: star.size
                        )
                        canvas.fill(Circle().path(in: rect), with: .color(.white.opacity(twinkle * 0.9)))
                    }

                    for puff in puffs {
                        let progress = (time * puff.speed + puff.x).truncatingRemainder(dividingBy: 1.3) - 0.15
                        let center = CGPoint(x: size.width * progress, y: size.height * puff.y)
                        let unit = 36 * puff.scale
                        let blobs: [(Double, Double, Double)] = [(0, 0, 1.0), (-1.1, 0.15, 0.72), (1.1, 0.1, 0.8), (-0.45, -0.45, 0.78), (0.5, -0.5, 0.7)]
                        for (dx, dy, radius) in blobs {
                            let r = unit * radius
                            let rect = CGRect(x: center.x + dx * unit - r, y: center.y + dy * unit - r, width: r * 2, height: r * 2)
                            canvas.fill(Circle().path(in: rect), with: .color(Theme.Colors.cloud.opacity(puff.alpha)))
                        }
                    }
                }
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    SkyBackdrop()
}
