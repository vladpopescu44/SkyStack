import SwiftUI

/// Which painted sky to show behind a screen.
enum SkyKind: String, CaseIterable {
    case day, dusk, night, storm

    var asset: String { "sky-\(rawValue)" }

    /// The sky climbs from day to dusk to night as the player's record grows.
    static func forHeight(_ height: Int) -> SkyKind {
        switch height {
        case ..<20: .day
        case ..<45: .dusk
        default: .night
        }
    }
}

/// Full-bleed painted sky with a few generated clouds drifting across it.
struct SkyScenery: View {
    var kind: SkyKind = .day
    var cloudCount = 3

    private static let clouds = ["cloud-a", "cloud-b", "cloud-c"]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image(kind.asset)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                if kind != .night {
                    TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                        let time = context.date.timeIntervalSinceReferenceDate
                        ZStack {
                            ForEach(0..<cloudCount, id: \.self) { index in
                                cloud(index: index, time: time, size: proxy.size)
                            }
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func cloud(index: Int, time: TimeInterval, size: CGSize) -> some View {
        let speed = 9.0 + Double(index) * 4
        let span = size.width + 320
        let x = (time * speed + Double(index) * 230).truncatingRemainder(dividingBy: span) - 160
        let y = size.height * (0.18 + 0.22 * Double(index))
        let width = 150.0 + Double(index % 2) * 60
        return Image(Self.clouds[index % Self.clouds.count])
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .opacity(kind == .storm ? 0.35 : 0.85)
            .position(x: x, y: y)
    }
}

#Preview {
    SkyScenery(kind: .dusk)
}
