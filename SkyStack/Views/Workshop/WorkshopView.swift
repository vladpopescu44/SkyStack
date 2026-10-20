import SwiftUI

/// The workshop: upgrades presented as chalk-on-blueprint plans that you pay stars to build.
struct WorkshopView: View {
    @State private var viewModel: WorkshopViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(viewModel: WorkshopViewModel) {
        self.viewModel = viewModel
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .top), count: sizeClass == .regular ? 2 : 1)
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        ZStack {
            Theme.Colors.blueprint
                .overlay(Image("blueprint-grid").resizable(resizingMode: .tile))
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    header
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(UpgradeKind.allCases) { kind in
                            BlueprintSheet(
                                kind: kind,
                                level: viewModel.level(of: kind),
                                cost: viewModel.nextCost(of: kind),
                                canAfford: viewModel.canPurchase(kind),
                                skin: viewModel.store.profile.selectedBuilder,
                                shakeTrigger: viewModel.shakeCounts[kind] ?? 0,
                                pulseTrigger: viewModel.pulseCounts[kind] ?? 0,
                                onBuild: { viewModel.purchase(kind) }
                            )
                        }
                    }
                }
                .frame(maxWidth: sizeClass == .regular ? 900 : Theme.Metrics.maxContentWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.Metrics.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .toast(message: $viewModel.toastMessage, isError: viewModel.toastIsError)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Workshop.screen)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("WORKSHOP")
                    .font(.display(30, weight: .black))
                    .foregroundStyle(Theme.Colors.chalk)
                Text("\(viewModel.maxedCount) of \(UpgradeKind.allCases.count) plans fully built")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.chalk.opacity(0.7))
            }
            Spacer()
            CoinBadge(amount: viewModel.stars)
                .padding(.top, 2)
        }
    }
}

/// One upgrade drawn as a blueprint: illustration, chalk notes, level blocks and a build button.
private struct BlueprintSheet: View {
    let kind: UpgradeKind
    let level: Int
    let cost: Int?
    let canAfford: Bool
    let skin: BuilderSkin
    let shakeTrigger: Int
    let pulseTrigger: Int
    let onBuild: () -> Void

    @State private var pulse = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(kind.illustration)
                .resizable()
                .scaledToFit()
                .frame(width: 78, height: 78)
                .padding(6)
                .background(Circle().fill(.white.opacity(0.08)))
                .overlay(Circle().strokeBorder(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                .scaleEffect(pulse ? 1.12 : 1)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(kind.title)
                        .font(.display(18))
                        .foregroundStyle(Theme.Colors.chalk)
                    Spacer()
                    Text("LV \(level)/\(kind.maxLevel)")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.Colors.chalk.opacity(0.7))
                }
                Text(kind.summary)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.chalk.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
                LevelBlocks(level: level, maxLevel: kind.maxLevel, skin: skin)
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(kind.effectDescription(atLevel: level))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.Colors.chalk.opacity(0.75))
                        if cost != nil {
                            Text("→ " + kind.effectDescription(atLevel: level + 1))
                                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                .foregroundStyle(Theme.Colors.sun)
                        }
                    }
                    Spacer(minLength: 4)
                    buildButton
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(cost == nil ? 0.85 : 0.5), style: StrokeStyle(lineWidth: 1.5, dash: cost == nil ? [] : [7, 5]))
                )
        }
        .overlay(alignment: .topLeading) { cornerTicks }
        .shake(trigger: shakeTrigger)
        .onChange(of: pulseTrigger) { _, _ in
            withAnimation(.spring(duration: 0.3, bounce: 0.6)) { pulse = true }
            withAnimation(.spring(duration: 0.4).delay(0.3)) { pulse = false }
        }
    }

    /// Little registration marks like on a printed plan.
    private var cornerTicks: some View {
        Path { path in
            path.move(to: CGPoint(x: 6, y: 16)); path.addLine(to: CGPoint(x: 6, y: 6)); path.addLine(to: CGPoint(x: 16, y: 6))
        }
        .stroke(.white.opacity(0.7), lineWidth: 2)
        .frame(width: 20, height: 20)
    }

    @ViewBuilder
    private var buildButton: some View {
        if let cost {
            Button(action: onBuild) {
                HStack(spacing: 5) {
                    Image("coin-star").resizable().scaledToFit().frame(width: 18, height: 18)
                    Text(Formatters.integer(cost))
                }
            }
            .buttonStyle(BlockButtonStyle(color: Theme.Colors.sun, compact: true, isEnabledLook: canAfford))
            .accessibilityLabel("Upgrade \(kind.title) for \(cost) stars")
            .accessibilityIdentifier(AccessibilityID.Workshop.upgradeButton(kind.id))
        } else {
            Text("BUILT")
                .font(.display(13, weight: .black))
                .foregroundStyle(Theme.Colors.blueprint)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Capsule().fill(Theme.Colors.chalk))
                .rotationEffect(.degrees(-6))
                .accessibilityIdentifier(AccessibilityID.Workshop.upgradeButton(kind.id))
        }
    }
}
