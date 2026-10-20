import SwiftUI

/// Tutorial shown before the first build and available any time from the base.
struct HowToPlayView: View {
    let isOnboarding: Bool
    let onContinue: (() -> Void)?

    private struct Step: Identifiable {
        let id: Int
        let title: String
        let detail: String
        let systemImage: String
        let tint: Color
    }

    private let steps: [Step] = [
        Step(id: 0, title: "Drop the block", detail: "A block swings above the tower. Tap anywhere (or press the drop button) to let it fall onto the floor below.", systemImage: "hand.tap.fill", tint: Theme.Colors.sky),
        Step(id: 1, title: "Overhang gets trimmed", detail: "Whatever sticks out past the floor below breaks off. The next block is only as wide as what stayed. Miss completely and the build is over.", systemImage: "scissors", tint: Theme.Colors.coral),
        Step(id: 2, title: "Land perfects", detail: "Drop within the perfect zone and the block snaps into place with no trimming. Streaks of perfects multiply your score.", systemImage: "scope", tint: Theme.Colors.star),
        Step(id: 3, title: "Read the wind", detail: "A banner warns which way the next gust will push. During a gust the block drifts and slides a little after it lands, so drop early against the wind.", systemImage: "wind", tint: Theme.Colors.cloud),
        Step(id: 4, title: "Watch the lean", detail: "Every off-centre drop tilts the tower. The lean meter at the top shows how close it is to toppling. Perfects pull it back toward centre.", systemImage: "scalemass.fill", tint: Theme.Colors.success),
        Step(id: 5, title: "Anchor to clouds", detail: "A cloud drifts across the tower now and then. Place a block while the cloud covers it to restore the width and reset the lean.", systemImage: "cloud.fill", tint: Theme.Colors.cloud),
        Step(id: 6, title: "Weather the storms", detail: "From floor 10 a five-floor storm rolls in, then again every twelve floors: stronger gusts, but every floor pays double stars and score.", systemImage: "cloud.bolt.rain.fill", tint: Theme.Colors.violet),
        Step(id: 7, title: "Light the Sky Lantern", detail: "Three perfects inside one storm light the lantern. The next three blocks centre themselves no matter the wind.", systemImage: "lightbulb.max.fill", tint: Theme.Colors.star),
        Step(id: 8, title: "Spend stars in the workshop", detail: "Stars earned while building buy a wider base, a bigger perfect zone, windbreaks, ballast against lean and a star multiplier.", systemImage: "wrench.and.screwdriver.fill", tint: Theme.Colors.sky)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if isOnboarding {
                    VStack(spacing: 6) {
                        Text("Welcome to the sky")
                            .font(.display(26))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("Nine things to know before your first build.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.top, 20)
                }

                ForEach(steps) { step in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: step.systemImage)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(step.tint)
                            .frame(width: 44, height: 44)
                            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(step.tint.opacity(0.15)))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.title)
                                .font(.display(16))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text(step.detail)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .cardBackground(cornerRadius: Theme.Metrics.smallCornerRadius + 4)
                }

                if let onContinue {
                    Button(action: onContinue) {
                        Label("Let's build", systemImage: "arrow.up.to.line")
                    }
                    .buttonStyle(SkyButtonStyle())
                    .padding(.top, 6)
                    .accessibilityIdentifier(AccessibilityID.HowToPlay.continueButton)
                }
            }
            .frame(maxWidth: Theme.Metrics.maxContentWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(SkyBackdrop(cloudCount: 4))
        .navigationTitle("How to play")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.HowToPlay.screen)
    }
}
