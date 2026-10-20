import SwiftUI

/// In-game HUD: a floor tag at the top, an altimeter along the left edge, the windsock and stars
/// on the right, a weather ribbon, and a spirit level for the lean at the bottom.
struct GameHUDView: View {
    let hud: GameHUDState
    let bestHeight: Int
    let perfectPulse: Int
    let usesDropButton: Bool
    let isVisible: Bool
    let onPause: () -> Void

    @State private var pulse = false

    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                ZStack(alignment: .top) {
                    HStack(alignment: .top) {
                        Button(action: onPause) { Image(systemName: "pause.fill") }
                            .buttonStyle(PaperIconButtonStyle(size: 46))
                            .accessibilityLabel("Pause")
                            .accessibilityIdentifier(AccessibilityID.Game.pauseButton)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 8) {
                            CoinBadge(amount: hud.stars, isCompact: true)
                            windsock
                        }
                    }
                    floorTag
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)

                weatherRibbon
                Spacer()
                spiritLevel
                    .padding(.bottom, usesDropButton ? 96 : 22)
            }

            altimeter
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 14)
        }
        .opacity(isVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: isVisible)
        .allowsHitTesting(isVisible)
        .onChange(of: perfectPulse) { _, _ in
            withAnimation(.spring(duration: 0.2, bounce: 0.6)) { pulse = true }
            withAnimation(.spring(duration: 0.35).delay(0.2)) { pulse = false }
        }
    }

    // MARK: - Floor tag

    private var floorTag: some View {
        VStack(spacing: 6) {
            VStack(spacing: -2) {
                Text(Formatters.integer(hud.height))
                    .font(.display(42, weight: .black))
                    .monospacedDigit()
                    .foregroundStyle(Theme.Colors.ink)
                    .contentTransition(.numericText(value: Double(hud.height)))
                    .animation(.spring(duration: 0.3), value: hud.height)
                    .accessibilityIdentifier(AccessibilityID.Game.heightLabel)
                Text(hud.height == 1 ? "FLOOR" : "FLOORS")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Theme.Colors.inkFaint)
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
            .padding(.horizontal, 22)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 22, bottomTrailingRadius: 22, topTrailingRadius: 8, style: .continuous)
                    .fill(.white)
                    .shadow(color: Theme.Colors.ink.opacity(0.22), radius: 0, x: 0, y: 4)
            )
            .scaleEffect(pulse ? 1.1 : 1)

            HStack(spacing: 6) {
                Text(Formatters.integer(hud.score))
                    .font(.display(14, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(hud.score)))
                    .accessibilityIdentifier(AccessibilityID.Game.scoreLabel)
                if hud.perfectStreak > 0 {
                    Text("PERFECT ×\(hud.perfectStreak)")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.Colors.ink)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.Colors.sun))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(Capsule().fill(Theme.Colors.ink.opacity(0.55)))
            .animation(.spring(duration: 0.3), value: hud.perfectStreak > 0)
        }
        .padding(.bottom, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(Formatters.floors(hud.height)), score \(hud.score)")
    }

    // MARK: - Altimeter (progress toward the record)

    /// A vertical gauge: the fill is the current tower, the flag is the record to beat.
    private var altimeter: some View {
        let scale = Double(max(Int(Double(max(bestHeight, hud.height, 8)) * 1.25), 10))
        let progress = min(1, Double(hud.height) / scale)
        let recordMark = Double(bestHeight) / scale
        let barHeight: CGFloat = 200
        return ZStack(alignment: .bottomLeading) {
            Capsule().fill(.white.opacity(0.4)).frame(width: 10, height: barHeight)
            Capsule()
                .fill(LinearGradient(colors: [Theme.Colors.sun, Theme.Colors.coral], startPoint: .bottom, endPoint: .top))
                .frame(width: 10, height: max(10, barHeight * progress))
                .animation(.spring(duration: 0.4), value: progress)
            if bestHeight > 0 {
                HStack(spacing: 3) {
                    Rectangle().fill(Theme.Colors.ink).frame(width: 16, height: 2)
                    Text("BEST \(bestHeight)")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(hud.height > bestHeight ? Theme.Colors.leaf : Theme.Colors.ink.opacity(0.75)))
                }
                .offset(x: -3, y: -(barHeight * recordMark) + 6)
            }
        }
        .frame(height: barHeight, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(bestHeight > 0 ? "Record \(bestHeight) floors" : "No record yet")
    }

    // MARK: - Mechanic 1: windsock

    @ViewBuilder
    private var windsock: some View {
        if hud.windPhase != .calm {
            VStack(spacing: 2) {
                Image("windsock")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 58, height: 42)
                    .scaleEffect(x: hud.windDirection == .left ? -1 : 1, y: 1)
                    .rotationEffect(.degrees(hud.windPhase == .gusting ? (hud.windDirection == .left ? 6 : -6) : 18), anchor: .leading)
                    .opacity(hud.windPhase == .warning ? 0.7 : 1)
                if hud.windPhase == .warning {
                    Text("SOON")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.Colors.ink)
                        .padding(.horizontal, 6)
                        .background(Capsule().fill(.white))
                }
            }
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(duration: 0.4), value: hud.windPhase)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(hud.windPhase == .warning ? "Gust coming from the \(hud.windDirection == .left ? "right" : "left")" : "Gust blowing \(hud.windDirection.title)")
        }
    }

    // MARK: - Mechanics 1, 3 and 4: one weather ribbon

    @ViewBuilder
    private var weatherRibbon: some View {
        VStack(spacing: 6) {
            if hud.windPhase == .warning {
                ribbon("Gust incoming, pushing \(hud.windDirection.title)!", image: "windsock", tint: Theme.Colors.coral)
            } else if hud.windPhase == .gusting {
                ribbon("\(hud.isStormWind ? "Storm gust" : "Gust") \(hud.windDirection.title) \(Int(hud.windRemaining.rounded(.up)))s", image: "windsock", tint: Theme.Colors.sky)
            }
            if hud.lanternFloors > 0 {
                ribbon("Sky Lantern: \(hud.lanternFloors) auto-centred", image: "lantern", tint: Theme.Colors.sun)
            } else if hud.isStorm {
                HStack(spacing: 6) {
                    ribbon("STORM · stars x2", image: "coin-star", tint: Theme.Colors.violet)
                    lanternPips
                }
            } else if let floors = hud.floorsUntilStorm, floors <= StormBand.warningFloors {
                ribbon(floors == 1 ? "Storm next floor" : "Storm in \(floors) floors", image: "lantern", tint: Theme.Colors.violet)
            }
            // At most two ribbons: the cloud hint only shows when no storm notice is up.
            if hud.hasCloud, !hud.isStorm, hud.lanternFloors == 0, (hud.floorsUntilStorm ?? 99) > StormBand.warningFloors || hud.windPhase == .calm {
                ribbon("Cloud passing: drop under it to anchor", image: "cloud-a", tint: Theme.Colors.sky)
            }
        }
        .animation(.spring(duration: 0.3), value: hud.windPhase)
        .animation(.spring(duration: 0.3), value: hud.hasCloud)
        .animation(.spring(duration: 0.3), value: hud.isStorm)
    }

    private var lanternPips: some View {
        HStack(spacing: 3) {
            ForEach(0..<SkyLantern.perfectsToCharge, id: \.self) { index in
                Image("coin-star")
                    .resizable()
                    .frame(width: 16, height: 16)
                    .saturation(index < hud.stormPerfects ? 1 : 0)
                    .opacity(index < hud.stormPerfects ? 1 : 0.5)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(Capsule().fill(.white))
        .animation(.spring(duration: 0.3), value: hud.stormPerfects)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Storm perfects \(hud.stormPerfects) of \(SkyLantern.perfectsToCharge)")
    }

    private func ribbon(_ text: String, image: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            ArtIcon(image: image, tint: tint, size: 24)
            Text(text)
                .font(.display(13, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.ink)
        }
        .padding(.vertical, 5)
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .background(Capsule().fill(.white))
        .overlay(alignment: .leading) { Capsule().fill(tint).frame(width: 4).padding(.vertical, 6) }
        .shadow(color: Theme.Colors.ink.opacity(0.2), radius: 0, x: 0, y: 3)
        .transition(.move(edge: .top).combined(with: .opacity))
        .id(text)
    }

    // MARK: - Mechanic 2: spirit level

    private var spiritLevel: some View {
        let severity = abs(hud.lean)
        return VStack(spacing: 2) {
            ZStack {
                Image("spirit-level")
                    .resizable()
                    .frame(width: 240, height: 37)
                Image("level-bubble")
                    .resizable()
                    .frame(width: 28, height: 18)
                    .offset(x: CGFloat(hud.lean) * 66, y: -1)
                    .animation(.easeOut(duration: 0.25), value: hud.lean)
            }
            .shadow(color: severity > 0.75 ? Theme.Colors.coral.opacity(0.9) : .clear, radius: 10)
            Text(severity > 0.75 ? "ABOUT TO TOPPLE" : "LEAN")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(severity > 0.75 ? Theme.Colors.coral : .white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(Theme.Colors.ink.opacity(0.85)))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lean \(Int(severity * 100)) percent")
    }
}
