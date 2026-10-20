import SwiftUI

/// Height, score, stars, lean meter and the wind / storm banners shown over the running scene.
struct GameHUDView: View {
    let hud: GameHUDState
    let perfectPulse: Int
    let isVisible: Bool
    let onPause: () -> Void

    @State private var pulse = false

    var body: some View {
        VStack(spacing: 10) {
            // Side columns take equal widths so the height card stays centred on screen.
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    StarBadge(amount: hud.stars, isCompact: true)
                    if hud.perfectStreak > 0 {
                        streakChip
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                heightBlock
                    .fixedSize()
                VStack(alignment: .trailing, spacing: 8) {
                    Button(action: onPause) {
                        Image(systemName: "pause.fill")
                    }
                    .buttonStyle(IconButtonStyle())
                    .accessibilityLabel("Pause")
                    .accessibilityIdentifier(AccessibilityID.Game.pauseButton)
                    if hud.hasCloud {
                        chip("Cloud!", systemImage: "cloud.fill", tint: Theme.Colors.cloud)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            leanMeter
            banners
            Spacer()
        }
        .opacity(isVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: isVisible)
        .animation(.spring(duration: 0.3), value: hud.hasCloud)
        .animation(.spring(duration: 0.3), value: hud.perfectStreak > 0)
        .allowsHitTesting(isVisible)
        .onChange(of: perfectPulse) { _, _ in
            withAnimation(.spring(duration: 0.2, bounce: 0.6)) { pulse = true }
            withAnimation(.spring(duration: 0.35).delay(0.2)) { pulse = false }
        }
    }

    // MARK: - Pieces

    private var heightBlock: some View {
        VStack(spacing: 0) {
            Text(Formatters.integer(hud.height))
                .font(.display(40, weight: .black))
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.textPrimary)
                .shadow(color: .black.opacity(0.6), radius: 6, y: 2)
                .contentTransition(.numericText(value: Double(hud.height)))
                .animation(.spring(duration: 0.3), value: hud.height)
                .scaleEffect(pulse ? 1.12 : 1)
                .accessibilityIdentifier(AccessibilityID.Game.heightLabel)
            Text(hud.height == 1 ? "FLOOR" : "FLOORS")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(2)
                .foregroundStyle(Theme.Colors.textTertiary)
            Text(Formatters.integer(hud.score))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.star)
                .contentTransition(.numericText(value: Double(hud.score)))
                .animation(.linear(duration: 0.1), value: hud.score)
                .accessibilityIdentifier(AccessibilityID.Game.scoreLabel)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.black.opacity(0.62))
        )
        // Keep the rolling digits inside the pill.
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(hud.height) floors, score \(hud.score)")
    }

    private var streakChip: some View {
        HStack(spacing: 5) {
            Image(systemName: "scope")
                .font(.system(size: 10, weight: .bold))
            Text("Perfect x\(hud.perfectStreak)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(Theme.Colors.star)
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(Capsule().fill(.black.opacity(0.4)))
        .shadow(color: Theme.Colors.star.opacity(0.6), radius: 8)
        .accessibilityElement(children: .combine)
    }

    /// Mechanic 2: the lean meter. The dot drifts toward the edge that is about to give way.
    private var leanMeter: some View {
        let severity = abs(hud.lean)
        let tint: Color = severity > 0.75 ? Theme.Colors.danger : (severity > 0.45 ? Theme.Colors.star : Theme.Colors.success)
        return HStack(spacing: 8) {
            Image(systemName: "arrow.left")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(hud.lean < -0.45 ? tint : Theme.Colors.textTertiary)
            GeometryReader { proxy in
                ZStack {
                    Capsule()
                        .fill(.white.opacity(0.14))
                    Rectangle()
                        .fill(.white.opacity(0.5))
                        .frame(width: 2, height: 10)
                    Circle()
                        .fill(tint)
                        .frame(width: 12, height: 12)
                        .shadow(color: tint.opacity(0.8), radius: 6)
                        .offset(x: CGFloat(hud.lean) * (proxy.size.width / 2 - 6))
                        .animation(.easeOut(duration: 0.2), value: hud.lean)
                }
            }
            .frame(width: 150, height: 8)
            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(hud.lean > 0.45 ? tint : Theme.Colors.textTertiary)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 12)
        .background(Capsule().fill(.black.opacity(0.45)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lean \(Int(severity * 100)) percent")
    }

    /// Mechanics 1 and 4: wind and storm context, one line each.
    @ViewBuilder
    private var banners: some View {
        windBanner
        stormBanner
    }

    @ViewBuilder
    private var windBanner: some View {
        switch hud.windPhase {
        case .calm:
            EmptyView()
        case .warning:
            bannerLabel(
                "Gust incoming, pushing \(hud.windDirection.title)!",
                systemImage: hud.windDirection.systemImage,
                tint: Theme.Colors.coral
            )
        case .gusting:
            bannerLabel(
                "\(hud.isStormWind ? "Storm gust" : "Gust") \(hud.windDirection.title) \(Int(hud.windRemaining.rounded(.up)))s",
                systemImage: "wind",
                tint: Theme.Colors.cloud
            )
        }
    }

    @ViewBuilder
    private var stormBanner: some View {
        if hud.lanternFloors > 0 {
            bannerLabel("Sky Lantern: \(hud.lanternFloors) auto-centred", systemImage: "lightbulb.max.fill", tint: Theme.Colors.star)
        } else if hud.isStorm {
            HStack(spacing: 8) {
                bannerLabel("STORM · stars x2", systemImage: "cloud.bolt.rain.fill", tint: Theme.Colors.violet)
                lanternPips
            }
        } else if let floors = hud.floorsUntilStorm, floors <= StormBand.warningFloors {
            bannerLabel(floors == 1 ? "Storm next floor" : "Storm in \(floors) floors", systemImage: "cloud.bolt.fill", tint: Theme.Colors.violet)
        }
    }

    /// Perfects landed inside the storm toward the next lantern.
    private var lanternPips: some View {
        HStack(spacing: 4) {
            ForEach(0..<SkyLantern.perfectsToCharge, id: \.self) { index in
                Image(systemName: index < hud.stormPerfects ? "star.fill" : "star")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(index < hud.stormPerfects ? Theme.Colors.star : .white.opacity(0.4))
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(Capsule().fill(.black.opacity(0.45)))
        .animation(.spring(duration: 0.3), value: hud.stormPerfects)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Storm perfects \(hud.stormPerfects) of \(SkyLantern.perfectsToCharge)")
    }

    private func chip(_ text: String, systemImage: String, tint: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(Capsule().fill(.black.opacity(0.4)))
    }

    private func bannerLabel(_ text: String, systemImage: String, tint: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.display(14, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.vertical, 7)
            .padding(.horizontal, 14)
            .background(Capsule().fill(.black.opacity(0.45)))
            .shadow(color: tint.opacity(0.5), radius: 10)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
            .id(text)
            .animation(.spring(duration: 0.3), value: text)
    }
}
