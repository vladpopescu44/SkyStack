import SwiftUI

/// The primary call-to-action style: a sky gradient pill that squashes when pressed.
struct SkyButtonStyle: ButtonStyle {
    var isProminent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(18, weight: .bold))
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .background {
                Capsule()
                    .fill(Theme.skyGradient)
                    .overlay {
                        Capsule()
                            .strokeBorder(.white.opacity(0.28), lineWidth: 1)
                    }
                    .shadow(color: Theme.Colors.skyDeep.opacity(isProminent ? 0.6 : 0.3), radius: configuration.isPressed ? 6 : 18, y: 8)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.35), value: configuration.isPressed)
    }
}

/// A quiet secondary style: translucent surface with a thin stroke.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(16, weight: .semibold))
            .foregroundStyle(Theme.Colors.textPrimary)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background {
                Capsule()
                    .fill(.white.opacity(configuration.isPressed ? 0.16 : 0.08))
                    .overlay {
                        Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1)
                    }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.3), value: configuration.isPressed)
    }
}

/// Compact style for inline actions such as "Upgrade" or "Select".
struct CompactSkyButtonStyle: ButtonStyle {
    var isEnabledLook = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background {
                Capsule()
                    .fill(isEnabledLook ? AnyShapeStyle(Theme.skyGradient) : AnyShapeStyle(Color.white.opacity(0.12)))
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.4), value: configuration.isPressed)
    }
}

/// Circular icon button used in the game HUD and navigation bars.
struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background {
                Circle()
                    .fill(.black.opacity(0.38))
                    .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))
            }
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.4), value: configuration.isPressed)
    }
}
