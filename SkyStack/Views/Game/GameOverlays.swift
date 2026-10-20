import SwiftUI

/// Shown before the build starts: a shift briefing sheet rising from the bottom.
struct ReadyOverlay: View {
    let builder: BuilderSkin
    let loadout: BuilderLoadout
    let bestScore: Int
    let bestHeight: Int
    let controlScheme: ControlScheme
    let onStart: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image("logo-wordmark")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 300)
                .padding(.top, 40)
                .shadow(color: Theme.Colors.ink.opacity(0.25), radius: 8, y: 4)
                .accessibilityHidden(true)
            Spacer()
            VStack(spacing: 14) {
                HStack(alignment: .bottom, spacing: 14) {
                    BuilderPortrait(skin: builder, height: 110, isAnimated: true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SHIFT BRIEFING")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(Theme.Colors.inkFaint)
                        Text(builder.title)
                            .font(.display(26, weight: .black))
                            .foregroundStyle(Theme.Colors.ink)
                        Text(bestHeight > 0 ? "Record \(Formatters.floors(bestHeight)) · best \(Formatters.integer(bestScore))" : "No record yet. Make one.")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Colors.inkSoft)
                    }
                    Spacer(minLength: 0)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6, alignment: .leading), GridItem(.flexible(), spacing: 6, alignment: .leading)], spacing: 6) {
                    InkChip(image: "upgrade-foundation", text: "Base \(Formatters.percent(loadout.foundationFraction))")
                    InkChip(image: "upgrade-precision", text: "Perfect ±\(Int(loadout.perfectTolerance.rounded())) pt")
                    InkChip(image: "upgrade-ballast", text: "Lean limit \(String(format: "%.1f", loadout.leanCapacity))")
                    InkChip(image: "upgrade-windbreak", text: "Gusts \(Formatters.percent(loadout.windbreakFactor))")
                }
                Label(
                    controlScheme == .tap ? "Tap anywhere on the sky to drop" : "Press DROP to place each block",
                    systemImage: controlScheme.systemImage
                )
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.sky)

                Button(action: onStart) {
                    Label("Start building", systemImage: "arrow.up.to.line")
                }
                .buttonStyle(BlockButtonStyle(color: Theme.Colors.coral))
                .accessibilityIdentifier(AccessibilityID.Game.startButton)

                Button("Back to the skyline", action: onQuit)
                    .buttonStyle(InkTextButtonStyle())
                    .accessibilityIdentifier(AccessibilityID.Game.quitButton)
            }
            .padding(20)
            .frame(maxWidth: 480)
            .paperPanel(cornerRadius: 30)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .background(
            LinearGradient(colors: [.clear, Theme.Colors.ink.opacity(0.35)], startPoint: .center, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }
}

/// 3-2-1 painted on a falling block.
struct CountdownOverlay: View {
    let value: Int
    let skin: BuilderSkin

    var body: some View {
        ZStack {
            Image(skin.blockAsset(forFloor: value))
                .resizable(capInsets: EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
                .frame(width: 150, height: 120)
                .shadow(color: Theme.Colors.ink.opacity(0.35), radius: 12, y: 6)
                .overlay {
                    Text("\(value)")
                        .font(.display(84, weight: .black))
                        .foregroundStyle(.white)
                        .shadow(color: Theme.Colors.ink.opacity(0.35), radius: 0, x: 0, y: 4)
                }
                .id(value)
                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .scale(scale: 0.6).combined(with: .opacity)))
                .animation(.spring(duration: 0.4, bounce: 0.45), value: value)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Starting in \(value)")
    }
}

/// Pause menu, pinned like a clipboard note.
struct PauseOverlay: View {
    let height: Int
    let score: Int
    let onResume: () -> Void
    let onRestart: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Theme.Colors.ink.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 14) {
                Image("windsock")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 46)
                    .rotationEffect(.degrees(24), anchor: .leading)
                    .accessibilityHidden(true)
                Text("Paused")
                    .font(.display(30, weight: .black))
                    .foregroundStyle(Theme.Colors.ink)
                HStack(spacing: 18) {
                    pauseStat(value: "\(height)", title: "floors")
                    pauseStat(value: Formatters.integer(score), title: "points")
                }
                Button(action: onResume) {
                    Label("Back to work", systemImage: "play.fill")
                }
                .buttonStyle(BlockButtonStyle(color: Theme.Colors.leaf))
                .accessibilityIdentifier(AccessibilityID.Game.resumeButton)

                Button(action: onRestart) {
                    Label("Start a new tower", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(BlockButtonStyle(color: Theme.Colors.sky))
                .accessibilityIdentifier(AccessibilityID.Game.restartButton)

                Button("Leave the site", action: onQuit)
                    .buttonStyle(InkTextButtonStyle())
                    .accessibilityIdentifier(AccessibilityID.Game.quitButton)
            }
            .padding(22)
            .frame(maxWidth: 360)
            .paperPanel(cornerRadius: 28)
            .padding(.horizontal, 24)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.Game.pausedOverlay)
        }
    }

    private func pauseStat(value: String, title: String) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.display(24))
                .foregroundStyle(Theme.Colors.ink)
                .monospacedDigit()
            Text(title.uppercased())
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(Theme.Colors.inkFaint)
        }
    }
}

/// Results as a site inspection report with a rubber stamp.
struct GameOverView: View {
    let outcome: RunOutcome
    let builder: BuilderSkin
    let onPlayAgain: () -> Void
    let onWorkshop: () -> Void
    let onQuit: () -> Void

    @State private var stamped = false

    private var stampText: String {
        if outcome.isNewHeightRecord { return "NEW\nRECORD" }
        return outcome.summary.toppled ? "TOPPLED" : "SLIPPED"
    }

    private var stampColor: Color {
        outcome.isNewHeightRecord || outcome.isNewBest ? Theme.Colors.leaf : Theme.Colors.coral
    }

    var body: some View {
        ZStack {
            Theme.Colors.ink.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("INSPECTION REPORT")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .tracking(1.5)
                    Spacer()
                    Text(Formatters.runDate(.now))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Theme.Colors.ink)

                VStack(spacing: 16) {
                    HStack(alignment: .center, spacing: 12) {
                        BuilderPortrait(skin: builder, height: 86)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(Formatters.floors(outcome.summary.height))
                                .font(.display(34, weight: .black))
                                .foregroundStyle(Theme.Colors.ink)
                            Text(outcome.isNewBest ? "Score \(Formatters.integer(outcome.summary.score)) · new best" : "Score \(Formatters.integer(outcome.summary.score)) · best \(Formatters.integer(outcome.previousBest))")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.Colors.inkSoft)
                        }
                        Spacer(minLength: 0)
                    }
                    .overlay(alignment: .topTrailing) { stamp }

                    VStack(spacing: 0) {
                        reportRow(icon: "coin-star", tint: Theme.Colors.sun, title: "Stars earned", value: "+\(Formatters.integer(outcome.summary.starsCollected))")
                        reportRow(icon: "upgrade-precision", tint: Theme.Colors.coral, title: "Perfect drops", value: Formatters.integer(outcome.summary.perfectPlacements))
                        reportRow(icon: "cloud-a", tint: Theme.Colors.sky, title: "Cloud anchors", value: Formatters.integer(outcome.summary.anchors))
                        reportRow(icon: "lantern", tint: Theme.Colors.sun, title: "Lanterns lit", value: Formatters.integer(outcome.summary.lanterns))
                        reportRow(icon: "upgrade-charm", tint: Theme.Colors.violet, title: "Star balance", value: Formatters.integer(outcome.totalStars), isLast: true)
                    }
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.Colors.paperShade))

                    Button(action: onPlayAgain) {
                        Label("Build again", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(BlockButtonStyle(color: Theme.Colors.coral))
                    .accessibilityIdentifier(AccessibilityID.Game.restartButton)

                    HStack(spacing: 10) {
                        Button(action: onWorkshop) {
                            Label("Workshop", systemImage: "hammer.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(BlockButtonStyle(color: Theme.Colors.blueprint, compact: true))
                        .accessibilityIdentifier(AccessibilityID.Game.workshopButton)
                        Button(action: onQuit) {
                            Label("Skyline", systemImage: "building.2.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(BlockButtonStyle(color: Theme.Colors.sky, compact: true))
                        .accessibilityIdentifier(AccessibilityID.Game.quitButton)
                    }
                }
                .padding(18)
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Theme.Colors.ink.opacity(0.35), radius: 20, y: 10)
            .frame(maxWidth: 420)
            .padding(.horizontal, 20)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.Game.gameOverOverlay)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.45, bounce: 0.5).delay(0.25)) { stamped = true }
        }
    }

    private var stamp: some View {
        Text(stampText)
            .font(.display(15, weight: .black))
            .multilineTextAlignment(.center)
            .foregroundStyle(stampColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(stampColor, lineWidth: 3))
            .rotationEffect(.degrees(-14))
            .scaleEffect(stamped ? 1 : 2.2)
            .opacity(stamped ? 0.9 : 0)
            .offset(x: 4, y: -6)
            .accessibilityLabel(stampText.replacingOccurrences(of: "\n", with: " "))
    }

    private func reportRow(icon: String, tint: Color, title: String, value: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ArtIcon(image: icon, tint: tint, size: 28)
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Colors.inkSoft)
                Spacer()
                Text(value)
                    .font(.system(size: 15, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Theme.Colors.ink)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            if !isLast {
                Rectangle()
                    .fill(Theme.Colors.ink.opacity(0.08))
                    .frame(height: 1)
                    .padding(.horizontal, 12)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
