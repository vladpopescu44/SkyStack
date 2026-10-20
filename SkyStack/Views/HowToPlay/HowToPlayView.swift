import SwiftUI

/// A swipeable illustrated guide. Shown before the first build and from the skyline's "?" button.
struct HowToPlayView: View {
    enum Mode {
        case onboarding
        case reference
    }

    let mode: Mode
    let onFinish: () -> Void

    @State private var page = 0

    private struct Page: Identifiable {
        let id: Int
        let art: String
        let title: String
        let detail: String
    }

    private let pages: [Page] = [
        Page(id: 0, art: "howto-drop", title: "Drop the block", detail: "A block swings above the tower. Tap anywhere on the sky (or press the drop button) to let it fall onto the floor below."),
        Page(id: 1, art: "howto-trim", title: "Overhang breaks off", detail: "Whatever sticks out past the floor below is trimmed away, so the next block is narrower. Miss completely and the build is over. Drop inside the perfect zone and nothing is lost."),
        Page(id: 2, art: "howto-wind", title: "Read the wind", detail: "A windsock and a banner warn which way the next gust will push. During a gust the block drifts and slides a little after it lands, so drop early against the wind."),
        Page(id: 3, art: "howto-lean", title: "Watch the spirit level", detail: "Every off-centre drop tilts the tower. When the bubble reaches the red end, the tower topples. Perfect drops pull it back toward the centre."),
        Page(id: 4, art: "howto-cloud", title: "Anchor to clouds", detail: "Now and then a cloud drifts past the top of the tower. Land a block while the cloud covers it to win back width and level the tower."),
        Page(id: 5, art: "howto-storm", title: "Weather the storms", detail: "From floor 10 a five-floor storm rolls in, then again every twelve floors. Gusts get stronger, but every storm floor pays double stars and score."),
        Page(id: 6, art: "howto-lantern", title: "Light the Sky Lantern", detail: "Three perfect drops inside one storm light the lantern. The next three blocks guide themselves to the centre, whatever the wind is doing."),
        Page(id: 7, art: "howto-workshop", title: "Spend stars in the workshop", detail: "Stars buy a wider base, steadier hands, windbreaks, ballast against lean and a star charm. New builders paint the tower in their own colours.")
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        ZStack {
            SkyScenery(kind: .day, cloudCount: 2)

            VStack(spacing: 16) {
                HStack {
                    Text(mode == .onboarding ? "Welcome aboard" : "How to play")
                        .font(.display(26, weight: .black))
                        .foregroundStyle(.white)
                        .shadow(color: Theme.Colors.ink.opacity(0.35), radius: 4, y: 2)
                    Spacer()
                    if mode == .reference {
                        Button(action: onFinish) { Image(systemName: "xmark") }
                            .buttonStyle(PaperIconButtonStyle(size: 40))
                            .accessibilityLabel("Close")
                            .accessibilityIdentifier(AccessibilityID.HowToPlay.closeButton)
                    }
                }

                TabView(selection: $page) {
                    ForEach(pages) { item in
                        pageCard(item).tag(item.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                progressBlocks

                HStack(spacing: 10) {
                    if page > 0 {
                        Button {
                            withAnimation(.spring(duration: 0.35)) { page -= 1 }
                        } label: {
                            Image(systemName: "arrow.left")
                        }
                        .buttonStyle(BlockButtonStyle(color: Theme.Colors.inkSoft, compact: true))
                        .accessibilityLabel("Back")
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    Button {
                        if isLast {
                            onFinish()
                        } else {
                            withAnimation(.spring(duration: 0.35)) { page += 1 }
                        }
                    } label: {
                        Label(isLast ? (mode == .onboarding ? "Let's build" : "Got it") : "Next", systemImage: isLast ? "arrow.up.to.line" : "arrow.right")
                    }
                    .buttonStyle(BlockButtonStyle(color: isLast ? Theme.Colors.coral : Theme.Colors.sky))
                    .accessibilityIdentifier(isLast ? AccessibilityID.HowToPlay.continueButton : AccessibilityID.HowToPlay.nextButton)
                }
                .animation(.spring(duration: 0.3), value: page > 0)
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.vertical, 12)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.HowToPlay.screen)
    }

    private func pageCard(_ item: Page) -> some View {
        VStack(spacing: 16) {
            Image(item.art)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 400)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityHidden(true)
            Text(item.title)
                .font(.display(22, weight: .black))
                .foregroundStyle(Theme.Colors.ink)
                .multilineTextAlignment(.center)
            Text(item.detail)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .paperPanel()
        .padding(.horizontal, 2)
        .frame(maxHeight: .infinity, alignment: .center)
    }

    /// Page indicator drawn as little blocks that stack up as you read.
    private var progressBlocks: some View {
        HStack(spacing: 5) {
            ForEach(pages) { item in
                Group {
                    if item.id <= page {
                        Image(BuilderSkin.starter.blockAsset(forFloor: item.id)).resizable()
                    } else {
                        RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.7))
                    }
                }
                .frame(width: item.id == page ? 30 : 20, height: 9)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 12)
        .background(Capsule().fill(Theme.Colors.ink.opacity(0.35)))
        .animation(.spring(duration: 0.3), value: page)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(page + 1) of \(pages.count)")
    }
}
