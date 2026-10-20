import SwiftUI

/// Dimmed backdrop shared by every overlay.
private struct OverlayScrim<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
            content
                .frame(maxWidth: 440)
                .padding(.horizontal, 24)
        }
    }
}

/// Shown before the build starts.
struct ReadyOverlay: View {
    let builder: BuilderSkin
    let loadout: BuilderLoadout
    let bestScore: Int
    let bestHeight: Int
    let controlScheme: ControlScheme
    let onStart: () -> Void
    let onQuit: () -> Void

    var body: some View {
        OverlayScrim {
            VStack(spacing: 18) {
                BuilderAvatarView(skin: builder, size: 120)
                VStack(spacing: 6) {
                    Text(builder.title)
                        .font(.display(26))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Best \(Formatters.integer(bestScore)) · \(Formatters.floors(bestHeight))")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                HStack(spacing: 8) {
                    StatChip(systemImage: "square.stack.3d.up.fill", text: "Base \(Formatters.percent(loadout.foundationFraction))")
                    StatChip(systemImage: "scope", text: "±\(Int(loadout.perfectTolerance.rounded())) pt", tint: Theme.Colors.star)
                    StatChip(systemImage: "scalemass.fill", text: "Lean \(String(format: "%.1f", loadout.leanCapacity))", tint: Theme.Colors.success)
                }
                Label(
                    controlScheme == .tap ? "Tap anywhere to drop the block" : "Press the drop button to place the block",
                    systemImage: controlScheme.systemImage
                )
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)

                Button(action: onStart) {
                    Label("Start building", systemImage: "arrow.up.to.line")
                }
                .buttonStyle(SkyButtonStyle())
                .accessibilityIdentifier(AccessibilityID.Game.startButton)

                Button("Back to base", action: onQuit)
                    .buttonStyle(GhostButtonStyle())
                    .accessibilityIdentifier(AccessibilityID.Game.quitButton)
            }
            .padding(26)
            .cardBackground()
        }
    }
}

/// Big animated number before the build begins.
struct CountdownOverlay: View {
    let value: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            Text("\(value)")
                .font(.display(120, weight: .black))
                .foregroundStyle(Theme.starGradient)
                .shadow(color: Theme.Colors.skyDeep.opacity(0.8), radius: 30)
                .id(value)
                .transition(.scale(scale: 1.6).combined(with: .opacity))
                .animation(.spring(duration: 0.4, bounce: 0.3), value: value)
        }
        .allowsHitTesting(false)
        .accessibilityLabel("Starting in \(value)")
    }
}

/// Pause menu.
struct PauseOverlay: View {
    let height: Int
    let score: Int
    let onResume: () -> Void
    let onRestart: () -> Void
    let onQuit: () -> Void

    var body: some View {
        OverlayScrim {
            VStack(spacing: 16) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.skyGradient)
                Text("Paused")
                    .font(.display(28))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("\(Formatters.floors(height)) · \(Formatters.integer(score)) points so far")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)

                Button(action: onResume) {
                    Label("Resume", systemImage: "play.fill")
                }
                .buttonStyle(SkyButtonStyle())
                .accessibilityIdentifier(AccessibilityID.Game.resumeButton)

                Button(action: onRestart) {
                    Label("Restart", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(GhostButtonStyle())
                .accessibilityIdentifier(AccessibilityID.Game.restartButton)

                Button("Quit to base", action: onQuit)
                    .buttonStyle(GhostButtonStyle())
                    .accessibilityIdentifier(AccessibilityID.Game.quitButton)
            }
            .padding(26)
            .cardBackground()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.Game.pausedOverlay)
        }
    }
}

/// Results card shown after the tower falls.
struct GameOverView: View {
    let outcome: RunOutcome
    let onPlayAgain: () -> Void
    let onWorkshop: () -> Void
    let onQuit: () -> Void

    @State private var revealed = false

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    private var headline: String {
        if outcome.isNewBest { return "NEW BEST!" }
        if outcome.isNewHeightRecord { return "Tallest tower yet!" }
        return outcome.summary.toppled ? "The tower toppled" : "The block slipped away"
    }

    var body: some View {
        OverlayScrim {
            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    Text(headline)
                        .font(.display(outcome.isNewBest ? 30 : 24, weight: .black))
                        .foregroundStyle(outcome.isNewBest ? AnyShapeStyle(Theme.starGradient) : AnyShapeStyle(Theme.Colors.textPrimary))
                        .shadow(color: outcome.isNewBest ? Theme.Colors.star.opacity(0.7) : .clear, radius: 16)
                        .multilineTextAlignment(.center)
                    Text(Formatters.integer(outcome.summary.score))
                        .font(.display(56, weight: .black))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(outcome.isNewBest
                         ? "Previous best \(Formatters.integer(outcome.previousBest))"
                         : "Best \(Formatters.integer(outcome.previousBest))")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ResultTile(title: "Height", value: Formatters.floors(outcome.summary.height), systemImage: "building.2.fill", tint: Theme.Colors.sky)
                    ResultTile(title: "Stars", value: "+\(Formatters.integer(outcome.summary.starsCollected))", systemImage: "star.fill", tint: Theme.Colors.star)
                    ResultTile(title: "Perfects", value: Formatters.integer(outcome.summary.perfectPlacements), systemImage: "scope", tint: Theme.Colors.success)
                    ResultTile(title: "Balance", value: Formatters.integer(outcome.totalStars), systemImage: "bag.fill", tint: Theme.Colors.violet)
                }

                Button(action: onPlayAgain) {
                    Label("Build again", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(SkyButtonStyle())
                .accessibilityIdentifier(AccessibilityID.Game.restartButton)

                HStack(spacing: 10) {
                    Button(action: onWorkshop) {
                        Label("Workshop", systemImage: "wrench.and.screwdriver.fill")
                    }
                    .buttonStyle(GhostButtonStyle())
                    Button(action: onQuit) {
                        Label("Base", systemImage: "house.fill")
                    }
                    .buttonStyle(GhostButtonStyle())
                    .accessibilityIdentifier(AccessibilityID.Game.quitButton)
                }
            }
            .padding(24)
            .cardBackground(isHighlighted: outcome.isNewBest)
            .scaleEffect(revealed ? 1 : 0.9)
            .opacity(revealed ? 1 : 0)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.Game.gameOverOverlay)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                revealed = true
            }
        }
    }
}

private struct ResultTile: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(tint.opacity(0.16)))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.display(17))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.06)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }
}
