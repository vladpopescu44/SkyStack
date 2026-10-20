import SwiftUI

/// The home screen: the player's own tower standing in a sky that darkens as the record grows.
struct SkylineView: View {
    let onShowGuide: () -> Void
    let onShowSettings: () -> Void
    let onOpenCrew: () -> Void

    @Environment(ProfileStore.self) private var store

    /// Height goals shown on the milestone ribbon.
    private static let milestones = [5, 10, 20, 35, 50, 75, 100, 150]

    var body: some View {
        let profile = store.profile
        ZStack {
            SkyScenery(kind: SkyKind.forHeight(profile.bestHeight))

            VStack(spacing: 14) {
                topBar
                milestoneRibbon(best: profile.bestHeight)
                Spacer(minLength: 0)
                SkylineTower(skin: profile.selectedBuilder, bestHeight: profile.bestHeight)
                crewTag(skin: profile.selectedBuilder)
            }
            .frame(maxWidth: Theme.Metrics.maxContentWidth)
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.top, 6)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Home.screen)
    }

    // MARK: - Pieces

    private var topBar: some View {
        HStack(alignment: .center, spacing: 10) {
            Image("logo-wordmark")
                .resizable()
                .scaledToFit()
                .frame(height: 50)
                .accessibilityLabel("Sky Stack")
            Spacer(minLength: 4)
            CoinBadge(amount: store.profile.stars)
                .accessibilityIdentifier(AccessibilityID.Home.starBalance)
            Button(action: onShowGuide) { Image(systemName: "questionmark") }
                .buttonStyle(PaperIconButtonStyle(size: 42))
                .accessibilityLabel("How to play")
                .accessibilityIdentifier(AccessibilityID.Home.howToPlayButton)
            Button(action: onShowSettings) { Image(systemName: "gearshape.fill") }
                .buttonStyle(PaperIconButtonStyle(size: 42))
                .accessibilityLabel("Settings")
                .accessibilityIdentifier(AccessibilityID.Home.settingsButton)
        }
    }

    private func milestoneRibbon(best: Int) -> some View {
        let target = Self.milestones.first { $0 > best } ?? (best + 50)
        let progress = Double(best) / Double(max(target, 1))
        // One segment per floor for short goals, tenths for longer ones.
        let segments = min(target, 10)
        let filled = Int((progress * Double(segments)).rounded(.down))

        return HStack(spacing: 12) {
            Image("upgrade-precision")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(best == 0 ? "First goal: \(target) floors" : "Next goal: \(target) floors")
                        .font(.display(15))
                        .foregroundStyle(Theme.Colors.ink)
                    Spacer()
                    Text("Best \(best)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.Colors.inkFaint)
                        .monospacedDigit()
                }
                HStack(spacing: 3) {
                    ForEach(0..<segments, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(index < filled ? Theme.Colors.sun : Theme.Colors.paperShade)
                            .frame(height: 8)
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .paperPanel(cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }

    private func crewTag(skin: BuilderSkin) -> some View {
        Button(action: onOpenCrew) {
            HStack(spacing: 10) {
                BuilderPortrait(skin: skin, height: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text("On shift: \(skin.title)")
                        .font(.display(15))
                        .foregroundStyle(Theme.Colors.ink)
                    Text("Change builder")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.sky)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Theme.Colors.inkFaint)
            }
            .padding(.vertical, 6)
            .padding(.leading, 8)
            .padding(.trailing, 16)
            .background(Capsule().fill(.white).shadow(color: Theme.Colors.ink.opacity(0.18), radius: 8, y: 4))
        }
        .buttonStyle(PressSquashStyle())
        .padding(.bottom, 12)
        .accessibilityLabel("On shift: \(skin.title). Change builder.")
        .accessibilityIdentifier(AccessibilityID.Home.crewTag)
    }
}

/// One floor of the miniature tower: block art with a row of windows, like in the game.
private struct MiniFloor: View {
    let asset: String
    let width: CGFloat
    let seed: Int

    var body: some View {
        Image(asset)
            .resizable(capInsets: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            .frame(width: width, height: 30)
            .overlay {
                HStack(spacing: 0) {
                    ForEach(0..<max(2, Int(width / 30)), id: \.self) { index in
                        Image((index + seed) % 3 == 0 ? "window-glass" : "window-lit")
                            .resizable()
                            .frame(width: 9, height: 11)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 6)
                .offset(y: 1)
            }
    }
}

/// A miniature of the player's record tower: building, stacked floors, a flag and the builder on top.
private struct SkylineTower: View {
    let skin: BuilderSkin
    let bestHeight: Int

    private var visibleFloors: Int { min(bestHeight, 7) }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                BuilderPortrait(skin: skin, height: 92, isAnimated: true)
                flag
                    .offset(x: -64, y: -40)
            }
            .offset(x: floorOffset(visibleFloors))

            ForEach((0..<visibleFloors).reversed(), id: \.self) { index in
                MiniFloor(asset: skin.blockAsset(forFloor: index + 1), width: floorWidth(index), seed: index)
                    .offset(x: floorOffset(index))
            }
            MiniFloor(asset: "block-base", width: 210, seed: 99)
            Image("tower-building")
                .resizable()
                .scaledToFill()
                .frame(width: 180, height: 120, alignment: .top)
                .clipped()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(bestHeight == 0 ? "Your tower has no floors yet" : "Your record tower: \(bestHeight) floors")
    }

    private var flag: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(bestHeight == 0 ? "READY" : "BEST \(bestHeight)")
                .font(.display(13, weight: .black))
                .foregroundStyle(.white)
                .padding(.vertical, 5)
                .padding(.horizontal, 9)
                .background(Theme.Colors.coral, in: UnevenRoundedRectangle(topLeadingRadius: 2, bottomLeadingRadius: 2, bottomTrailingRadius: 8, topTrailingRadius: 8))
            Rectangle()
                .fill(Theme.Colors.ink.opacity(0.6))
                .frame(width: 3, height: 34)
        }
    }

    private func floorWidth(_ index: Int) -> CGFloat {
        200 - CGFloat(index) * 8
    }

    /// Small deterministic offsets so the miniature looks hand-stacked.
    private func floorOffset(_ index: Int) -> CGFloat {
        let pattern: [CGFloat] = [0, 6, -5, 8, -3, 5, -6, 2]
        return pattern[index % pattern.count]
    }
}
