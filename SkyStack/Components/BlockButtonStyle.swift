import SwiftUI

/// A chunky "tower block" button: a coloured face sitting on a darker slab that sinks when pressed.
struct BlockButtonStyle: ButtonStyle {
    var color: Color = Theme.Colors.sky
    var compact = false
    var isEnabledLook = true

    func makeBody(configuration: Configuration) -> some View {
        let depth: CGFloat = compact ? 4 : 6
        let shift = configuration.isPressed ? depth * 0.75 : 0
        let radius: CGFloat = compact ? 14 : 20
        let face = isEnabledLook ? color : Theme.Colors.disabled

        configuration.label
            .font(.display(compact ? 15 : 19, weight: .heavy))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.2), radius: 0, x: 0, y: 1.5)
            .lineLimit(1)
            .padding(.vertical, compact ? 10 : 15)
            .padding(.horizontal, compact ? 16 : 22)
            .frame(maxWidth: compact ? nil : .infinity)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(face)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(LinearGradient(colors: [.white.opacity(0.35), .clear, .black.opacity(0.08)], startPoint: .top, endPoint: .bottom))
                    }
                    .overlay(alignment: .top) {
                        Capsule().fill(.white.opacity(0.45)).frame(height: 3).padding(.horizontal, radius * 0.7).padding(.top, 4)
                    }
            }
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(face)
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(.black.opacity(0.3)))
                    .offset(y: depth - shift)
            }
            .offset(y: shift)
            .padding(.bottom, depth)
            .animation(.spring(duration: 0.18, bounce: 0.4), value: configuration.isPressed)
    }
}

/// A round paper button used for icons over the sky (pause, settings, help).
struct PaperIconButtonStyle: ButtonStyle {
    var size: CGFloat = 46

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.38, weight: .heavy))
            .foregroundStyle(Theme.Colors.ink)
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(.white)
                    .shadow(color: Theme.Colors.ink.opacity(0.22), radius: 0, x: 0, y: configuration.isPressed ? 1 : 4)
            }
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(.spring(duration: 0.18, bounce: 0.4), value: configuration.isPressed)
    }
}

/// Plain text button for secondary actions on paper panels.
struct InkTextButtonStyle: ButtonStyle {
    var color: Color = Theme.Colors.inkSoft

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(16, weight: .bold))
            .foregroundStyle(color)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}
