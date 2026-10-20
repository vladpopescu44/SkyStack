import SwiftUI

/// White paper panel floating over the sky art.
struct PaperPanel: ViewModifier {
    var cornerRadius: CGFloat = Theme.Metrics.cornerRadius
    var tint: Color = .white

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Theme.Colors.ink.opacity(0.07), lineWidth: 1.5)
                    )
                    .shadow(color: Theme.Colors.ink.opacity(0.18), radius: 14, y: 7)
            }
    }
}

extension View {
    func paperPanel(cornerRadius: CGFloat = Theme.Metrics.cornerRadius, tint: Color = .white) -> some View {
        modifier(PaperPanel(cornerRadius: cornerRadius, tint: tint))
    }
}

/// Horizontal shake used to signal a rejected action.
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 8
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let offset = travel * sin(animatableData * .pi * shakes * 2)
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}

extension View {
    /// Shakes the view each time `trigger` changes.
    func shake(trigger: Int) -> some View {
        modifier(ShakeEffect(animatableData: CGFloat(trigger)))
            .animation(.linear(duration: 0.4), value: trigger)
    }
}

/// Star coin and amount on a paper pill.
struct CoinBadge: View {
    let amount: Int
    var isCompact = false

    var body: some View {
        HStack(spacing: isCompact ? 4 : 6) {
            Image("coin-star")
                .resizable()
                .scaledToFit()
                .frame(width: isCompact ? 22 : 28, height: isCompact ? 22 : 28)
            Text(Formatters.integer(amount))
                .font(.display(isCompact ? 15 : 18, weight: .heavy))
                .foregroundStyle(Theme.Colors.ink)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(amount)))
                .animation(.spring(duration: 0.4), value: amount)
        }
        .padding(.leading, 4)
        .padding(.trailing, isCompact ? 10 : 14)
        .padding(.vertical, 4)
        .background(Capsule().fill(.white).shadow(color: Theme.Colors.ink.opacity(0.2), radius: 0, x: 0, y: 3))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(amount) stars")
    }
}

/// Small rounded label used for stats on paper.
struct InkChip: View {
    let image: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.inkSoft)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.vertical, 4)
        .padding(.leading, 5)
        .padding(.trailing, 9)
        .background(Capsule().fill(Theme.Colors.paperShade))
    }
}

/// The equipped builder's generated portrait.
struct BuilderPortrait: View {
    let skin: BuilderSkin
    var height: CGFloat = 120
    var isAnimated = false

    @State private var bob = false

    var body: some View {
        Image(skin.portraitAsset)
            .resizable()
            .scaledToFit()
            .frame(width: height * 360 / 420, height: height)
            .offset(y: bob ? -3 : 0)
            .onAppear {
                guard isAnimated else { return }
                withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { bob = true }
            }
            .accessibilityHidden(true)
    }
}

/// Level meter drawn as a short stack of real block textures.
struct LevelBlocks: View {
    let level: Int
    let maxLevel: Int
    var skin: BuilderSkin = .starter
    var emptyColor: Color = .white.opacity(0.6)

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<maxLevel, id: \.self) { index in
                Group {
                    if index < level {
                        Image(skin.blockAsset(forFloor: index))
                            .resizable(capInsets: EdgeInsets(top: 3, leading: 5, bottom: 3, trailing: 5))
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(emptyColor.opacity(0.35))
                            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(emptyColor, lineWidth: 1.2))
                    }
                }
                .frame(width: 26, height: 9)
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.4), value: level)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(level) of \(maxLevel)")
    }
}

/// A small art icon on a tinted disc so light artwork stays visible on white paper.
struct ArtIcon: View {
    let image: String
    var tint: Color = Theme.Colors.sky
    var size: CGFloat = 26

    var body: some View {
        Image(image)
            .resizable()
            .scaledToFit()
            .padding(size * 0.14)
            .frame(width: size, height: size)
            .background(Circle().fill(tint.opacity(0.22)))
    }
}

/// Section title in the app's ink-on-paper style.
struct InkHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.display(19))
                .foregroundStyle(Theme.Colors.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Colors.inkFaint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
