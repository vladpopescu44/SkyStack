import SwiftUI

/// SwiftUI rendition of the in-game builder so menus and the scene share one look.
struct BuilderAvatarView: View {
    let skin: BuilderSkin
    var size: CGFloat = 96
    var isAnimated = true

    @State private var bob = false

    var body: some View {
        let scale = size / 96
        ZStack {
            // Ambient glow behind the builder.
            Circle()
                .fill(skin.glow.color.opacity(0.32))
                .frame(width: size * 0.95, height: size * 0.95)
                .blur(radius: 14 * scale)
                .scaleEffect(bob ? 1.08 : 0.94)

            // Small cloud the builder floats on.
            HStack(spacing: -8 * scale) {
                Circle().frame(width: 18 * scale, height: 18 * scale)
                Circle().frame(width: 26 * scale, height: 26 * scale)
                Circle().frame(width: 18 * scale, height: 18 * scale)
            }
            .foregroundStyle(Theme.Colors.cloud.opacity(0.9))
            .offset(y: 38 * scale)
            .scaleEffect(x: bob ? 1.08 : 0.95, y: 1)

            VStack(spacing: -5 * scale) {
                // Head with hard hat and goggles.
                ZStack {
                    Circle()
                        .fill(skin.primary.color)
                        .overlay(Circle().strokeBorder(skin.secondary.color, lineWidth: 2.5 * scale))
                        .frame(width: 30 * scale, height: 30 * scale)
                    // Hat dome.
                    Capsule()
                        .fill(skin.secondary.color)
                        .frame(width: 32 * scale, height: 14 * scale)
                        .clipShape(Rectangle().offset(y: -3 * scale))
                        .offset(y: -11 * scale)
                    // Hat brim.
                    Capsule()
                        .fill(skin.secondary.color)
                        .frame(width: 38 * scale, height: 5 * scale)
                        .offset(y: -6 * scale)
                    // Goggles.
                    Capsule()
                        .fill(skin.glow.color)
                        .frame(width: 18 * scale, height: 7 * scale)
                        .shadow(color: skin.glow.color, radius: 3 * scale)
                        .offset(y: 1 * scale)
                }
                .offset(y: bob ? -2 * scale : 2 * scale)
                .zIndex(1)

                // Body with tool belt.
                ZStack {
                    RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
                        .fill(skin.primary.color)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
                                .strokeBorder(skin.secondary.color, lineWidth: 2.5 * scale)
                        )
                        .frame(width: 32 * scale, height: 40 * scale)
                    RoundedRectangle(cornerRadius: 2 * scale)
                        .fill(skin.secondary.color)
                        .frame(width: 26 * scale, height: 5 * scale)
                        .offset(y: 8 * scale)
                    Image(systemName: "star.fill")
                        .font(.system(size: 9 * scale, weight: .bold))
                        .foregroundStyle(skin.glow.color)
                        .shadow(color: skin.glow.color, radius: 2 * scale)
                        .offset(y: -5 * scale)
                }
            }
            .offset(y: -4 * scale)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard isAnimated else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                bob = true
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        ForEach(BuilderSkin.allCases) { skin in
            BuilderAvatarView(skin: skin, size: 80)
        }
    }
    .padding()
    .background(Theme.Colors.background)
}
