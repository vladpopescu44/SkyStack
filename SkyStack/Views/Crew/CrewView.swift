import SwiftUI

/// The crew: swipe through builders standing on a cloud, unlock them with stars and pick who is on shift.
struct CrewView: View {
    @State private var viewModel: BuildersViewModel
    @State private var focused: BuilderSkin

    init(viewModel: BuildersViewModel) {
        self.viewModel = viewModel
        self.focused = viewModel.selected
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        ZStack {
            SkyScenery(kind: .dusk, cloudCount: 2)

            VStack(spacing: 10) {
                header
                TabView(selection: $focused) {
                    ForEach(BuilderSkin.allCases) { skin in
                        CrewPage(
                            skin: skin,
                            status: viewModel.status(of: skin),
                            canAfford: viewModel.canUnlock(skin),
                            shakeTrigger: viewModel.shakeCounts[skin] ?? 0,
                            onActivate: { viewModel.activate(skin) }
                        )
                        .tag(skin)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                roster
            }
            .frame(maxWidth: Theme.Metrics.maxContentWidth)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
        .toast(message: $viewModel.toastMessage, isError: viewModel.toastIsError)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Builders.screen)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("CREW")
                    .font(.display(30, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: Theme.Colors.ink.opacity(0.4), radius: 4, y: 2)
                Text("Swipe to meet the builders")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            CoinBadge(amount: viewModel.stars)
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
    }

    /// Thumbnails for jumping straight to a builder.
    private var roster: some View {
        HStack(spacing: 8) {
            ForEach(BuilderSkin.allCases) { skin in
                let isFocused = focused == skin
                let isUnlocked = viewModel.store.profile.isUnlocked(skin)
                Button {
                    withAnimation(.spring(duration: 0.35)) { focused = skin }
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        Image(skin.portraitAsset)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 46)
                            .saturation(isUnlocked ? 1 : 0)
                            .opacity(isUnlocked ? 1 : 0.6)
                            .frame(width: 50, height: 54)
                            .background(Circle().fill(isFocused ? .white : .white.opacity(0.35)))
                        if viewModel.selected == skin {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.Colors.leaf, .white)
                        } else if !isUnlocked {
                            Image(systemName: "lock.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.Colors.ink, .white)
                        }
                    }
                    .scaleEffect(isFocused ? 1.08 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(skin.title)
                .accessibilityIdentifier(AccessibilityID.Builders.thumbnail(skin.id))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Capsule().fill(.white.opacity(0.25)))
    }
}

/// One builder standing on a cloud podium with their palette and the unlock or select action.
private struct CrewPage: View {
    let skin: BuilderSkin
    let status: BuildersViewModel.Status
    let canAfford: Bool
    let shakeTrigger: Int
    let onActivate: () -> Void

    private var isLocked: Bool {
        if case .locked = status { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                Image("podium-cloud")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 280)
                    .offset(y: 34)
                BuilderPortrait(skin: skin, height: 210, isAnimated: !isLocked)
                    .saturation(isLocked ? 0 : 1)
                    .colorMultiply(isLocked ? Color(white: 0.62) : .white)
                    .overlay(alignment: .topLeading) {
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Theme.Colors.ink)
                                .padding(10)
                                .background(Circle().fill(.white))
                        }
                    }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 30)

            VStack(spacing: 10) {
                Text(skin.title)
                    .font(.display(26, weight: .black))
                    .foregroundStyle(Theme.Colors.ink)
                Text(skin.lore)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
                paletteStrip
                actionButton
            }
            .padding(18)
            .frame(maxWidth: 360)
            .paperPanel()
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .shake(trigger: shakeTrigger)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Builders.card(skin.id))
    }

    /// The block colours this builder stacks with, as a tiny tower lying on its side.
    private var paletteStrip: some View {
        HStack(spacing: 3) {
            ForEach(0..<skin.blockPalette.count, id: \.self) { index in
                Image(skin.blockAsset(forFloor: index))
                    .resizable()
                    .frame(width: 36, height: 12)
            }
        }
        .saturation(isLocked ? 0.25 : 1)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch status {
        case .equipped:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                Text("EQUIPPED")
            }
            .font(.display(15, weight: .black))
            .foregroundStyle(Theme.Colors.leaf)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(Theme.Colors.leaf.opacity(0.12)))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("EQUIPPED")
            .accessibilityIdentifier(AccessibilityID.Builders.action(skin.id))
        case .unlocked:
            Button("Put on shift", action: onActivate)
                .buttonStyle(BlockButtonStyle(color: Theme.Colors.sky))
                .accessibilityIdentifier(AccessibilityID.Builders.action(skin.id))
        case .locked(let price):
            Button(action: onActivate) {
                HStack(spacing: 6) {
                    Text("Hire for")
                    Image("coin-star").resizable().scaledToFit().frame(width: 22, height: 22)
                    Text(Formatters.integer(price))
                }
            }
            .buttonStyle(BlockButtonStyle(color: Theme.Colors.coral, isEnabledLook: canAfford))
            .accessibilityLabel("Unlock \(skin.title) for \(price) stars")
            .accessibilityIdentifier(AccessibilityID.Builders.action(skin.id))
        }
    }
}
