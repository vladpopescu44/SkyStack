import SwiftUI

/// The base screen: builder overview, play button and navigation to every other screen.
struct HomeView: View {
    let onPlay: () -> Void

    @Environment(ProfileStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var playPulse = false

    private var menuColumns: [GridItem] {
        let count = sizeClass == .regular ? 4 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 14), count: count)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                builderCard
                playButton
                LazyVGrid(columns: menuColumns, spacing: 14) {
                    MenuCard(
                        title: "Workshop",
                        subtitle: "\(maxedUpgrades)/\(UpgradeKind.allCases.count) maxed",
                        systemImage: "wrench.and.screwdriver.fill",
                        tint: Theme.Colors.sky,
                        route: .workshop
                    )
                    .accessibilityIdentifier(AccessibilityID.Home.workshopButton)
                    MenuCard(
                        title: "Builders",
                        subtitle: "\(unlockedBuilders)/\(BuilderSkin.allCases.count) unlocked",
                        systemImage: "person.2.fill",
                        tint: Theme.Colors.violet,
                        route: .builders
                    )
                    .accessibilityIdentifier(AccessibilityID.Home.buildersButton)
                    MenuCard(
                        title: "Records",
                        subtitle: "Best \(Formatters.integer(store.profile.bestScore))",
                        systemImage: "trophy.fill",
                        tint: Theme.Colors.star,
                        route: .records
                    )
                    .accessibilityIdentifier(AccessibilityID.Home.recordsButton)
                    MenuCard(
                        title: "How to play",
                        subtitle: "Wind, lean & storms",
                        systemImage: "questionmark.circle.fill",
                        tint: Theme.Colors.success,
                        route: .howToPlay
                    )
                    .accessibilityIdentifier(AccessibilityID.Home.howToPlayButton)
                }
            }
            .frame(maxWidth: Theme.Metrics.maxContentWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(SkyBackdrop())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.settings) {
                    Image(systemName: "gearshape.fill")
                }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("Settings")
                .accessibilityIdentifier(AccessibilityID.Home.settingsButton)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Home.screen)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                playPulse = true
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SKY STACK")
                    .font(.display(34, weight: .black))
                    .foregroundStyle(Theme.skyGradient)
                    .shadow(color: Theme.Colors.skyDeep.opacity(0.6), radius: 12)
                Text("Build above the clouds.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            StarBadge(amount: store.profile.stars)
                .accessibilityIdentifier(AccessibilityID.Home.starBalance)
        }
        .padding(.top, 4)
    }

    private var builderCard: some View {
        let loadout = store.loadout
        return NavigationLink(value: Route.builders) {
            HStack(spacing: 18) {
                BuilderAvatarView(skin: loadout.skin, size: 104)
                VStack(alignment: .leading, spacing: 8) {
                    Text(loadout.skin.title)
                        .font(.display(22))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(loadout.skin.lore)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(2)
                    // Chips never wrap: the row scrolls if a narrow screen cannot fit them.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            StatChip(systemImage: "square.stack.3d.up.fill", text: Formatters.percent(loadout.foundationFraction))
                            StatChip(systemImage: "scope", text: "Lv \(loadout.precision)", tint: Theme.Colors.star)
                            StatChip(systemImage: "wind", text: "Lv \(loadout.windbreak)", tint: Theme.Colors.cloud)
                            StatChip(systemImage: "scalemass.fill", text: "Lv \(loadout.ballast)", tint: Theme.Colors.success)
                        }
                        .fixedSize()
                    }
                    .scrollClipDisabled()
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .padding(18)
            .cardBackground()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Current builder: \(loadout.skin.title). Open builders.")
    }

    private var playButton: some View {
        Button(action: onPlay) {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                Text("BUILD")
                    .tracking(2)
            }
            .font(.display(22, weight: .black))
        }
        .buttonStyle(SkyButtonStyle())
        .shadow(color: Theme.Colors.sky.opacity(playPulse ? 0.7 : 0.25), radius: playPulse ? 26 : 12)
        .accessibilityIdentifier(AccessibilityID.Home.playButton)
    }

    private var maxedUpgrades: Int {
        UpgradeKind.allCases.filter { store.level(of: $0) >= $0.maxLevel }.count
    }

    private var unlockedBuilders: Int {
        BuilderSkin.allCases.filter { store.profile.isUnlocked($0) }.count
    }
}

/// A navigation tile on the home grid.
private struct MenuCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let route: Route

    var body: some View {
        NavigationLink(value: route) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(tint.opacity(0.16)))
                Spacer(minLength: 0)
                Text(title)
                    .font(.display(17))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
            .padding(16)
            .cardBackground(cornerRadius: Theme.Metrics.smallCornerRadius + 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}
