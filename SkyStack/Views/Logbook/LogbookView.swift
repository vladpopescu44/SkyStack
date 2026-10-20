import Charts
import SwiftUI

/// The logbook: record tower, a chart of recent towers, achievement stamps and the build history.
struct LogbookView: View {
    @Environment(ProfileStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var stampColumns: [GridItem] {
        [GridItem(.adaptive(minimum: sizeClass == .regular ? 120 : 98), spacing: 12)]
    }

    var body: some View {
        let profile = store.profile
        ZStack(alignment: .top) {
            SkyScenery(kind: SkyKind.forHeight(profile.bestHeight), cloudCount: 1)

            ScrollView {
                VStack(spacing: 18) {
                    header
                    recordCard(profile)
                    chartCard
                    stamps
                    history
                }
                .frame(maxWidth: Theme.Metrics.maxContentWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.Metrics.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Records.screen)
    }

    private var header: some View {
        HStack {
            Text("LOGBOOK")
                .font(.display(30, weight: .black))
                .foregroundStyle(.white)
                .shadow(color: Theme.Colors.ink.opacity(0.35), radius: 4, y: 2)
            Spacer()
            CoinBadge(amount: store.profile.stars)
        }
    }

    private func recordCard(_ profile: PlayerProfile) -> some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text("\(profile.bestHeight)")
                    .font(.display(52, weight: .black))
                    .foregroundStyle(Theme.Colors.ink)
                    .monospacedDigit()
                Text("FLOOR RECORD")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(Theme.Colors.inkFaint)
            }
            .frame(minWidth: 110)
            Rectangle().fill(Theme.Colors.paperShade).frame(width: 2)
            VStack(alignment: .leading, spacing: 8) {
                statLine(icon: "upgrade-charm", tint: Theme.Colors.violet, title: "Best score", value: Formatters.integer(profile.bestScore))
                statLine(icon: "coin-star", tint: Theme.Colors.sun, title: "Stars earned", value: Formatters.integer(profile.totalStarsCollected))
                statLine(icon: "upgrade-foundation", tint: Theme.Colors.sky, title: "Builds", value: Formatters.integer(profile.totalRuns))
                statLine(icon: "upgrade-precision", tint: Theme.Colors.coral, title: "Perfect drops", value: Formatters.integer(profile.totalPerfects))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .paperPanel()
        .accessibilityElement(children: .combine)
    }

    private func statLine(icon: String, tint: Color, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            ArtIcon(image: icon, tint: tint, size: 26)
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.inkSoft)
            Spacer(minLength: 4)
            Text(value)
                .font(.display(15))
                .foregroundStyle(Theme.Colors.ink)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var chartCard: some View {
        let runs = Array(store.recentRuns.prefix(12).reversed())
        VStack(alignment: .leading, spacing: 12) {
            InkHeader(title: "Recent towers", subtitle: runs.isEmpty ? nil : "Height of your last \(runs.count) builds")
            if runs.isEmpty {
                VStack(spacing: 10) {
                    Image("tower-building")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 70, alignment: .top)
                        .clipped()
                        .opacity(0.6)
                    Text("No builds yet")
                        .font(.display(17))
                        .foregroundStyle(Theme.Colors.ink)
                    Text("Finish a build and its height will appear here as a bar, next to your record line.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.Colors.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(AccessibilityID.Records.emptyState)
            } else {
                Chart {
                    ForEach(Array(runs.enumerated()), id: \.offset) { index, run in
                        BarMark(
                            x: .value("Build", index + 1),
                            y: .value("Floors", run.height)
                        )
                        .foregroundStyle(run.builder.blockPalette[index % run.builder.blockPalette.count].color.gradient)
                        .cornerRadius(5)
                        .accessibilityLabel("Build \(index + 1)")
                        .accessibilityValue(Formatters.floors(run.height))
                    }
                    if store.profile.bestHeight > 0 {
                        RuleMark(y: .value("Record", store.profile.bestHeight))
                            .foregroundStyle(Theme.Colors.coral)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                            .annotation(position: .top, alignment: .leading) {
                                Text("Record \(store.profile.bestHeight)")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Theme.Colors.coral)
                            }
                    }
                }
                .chartXScale(domain: 0.4...(Double(runs.count) + 0.6))
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(Theme.Colors.paperShade)
                        AxisValueLabel().foregroundStyle(Theme.Colors.inkFaint)
                    }
                }
                .frame(height: 170)
                .accessibilityIdentifier(AccessibilityID.Records.chart)
            }
        }
        .padding(18)
        .paperPanel()
    }

    private var stamps: some View {
        let achievements = store.achievements
        return VStack(alignment: .leading, spacing: 12) {
            InkHeader(title: "Stamps", subtitle: "\(achievements.filter(\.isUnlocked).count) of \(achievements.count) collected")
            LazyVGrid(columns: stampColumns, spacing: 14) {
                ForEach(achievements) { achievement in
                    StampView(achievement: achievement)
                }
            }
        }
        .padding(18)
        .paperPanel()
    }

    @ViewBuilder
    private var history: some View {
        if !store.recentRuns.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                InkHeader(title: "Site log", subtitle: "Your last \(min(store.recentRuns.count, ProfileStore.recentRunLimit)) builds")
                ForEach(store.recentRuns) { run in
                    HistoryRow(run: run, isBest: run.score == store.profile.bestScore && run.score > 0)
                    if run.id != store.recentRuns.last?.id {
                        Rectangle().fill(Theme.Colors.paperShade).frame(height: 1.5)
                    }
                }
            }
            .padding(18)
            .paperPanel()
        }
    }
}

/// An achievement as a postage-style stamp: gold when earned, grey with progress otherwise.
private struct StampView: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Image(achievement.isUnlocked ? "stamp-earned" : "stamp-locked")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70, height: 70)
                Image(systemName: achievement.systemImage)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(achievement.isUnlocked ? .white : .white.opacity(0.45))
            }
            .rotationEffect(.degrees(achievement.isUnlocked ? -6 : 0))
            Text(achievement.title)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(achievement.isUnlocked ? Theme.Colors.ink : Theme.Colors.inkFaint)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
            Text(achievement.isUnlocked ? "Earned" : Formatters.percent(achievement.progress))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(achievement.isUnlocked ? Theme.Colors.leaf : Theme.Colors.inkFaint)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(achievement.title). \(achievement.detail) \(achievement.isUnlocked ? "Earned." : "\(Formatters.percent(achievement.progress)) done.")")
    }
}

private struct HistoryRow: View {
    let run: RunRecord
    let isBest: Bool

    var body: some View {
        HStack(spacing: 12) {
            BuilderPortrait(skin: run.builder, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(Formatters.floors(run.height))
                        .font(.display(16))
                        .foregroundStyle(Theme.Colors.ink)
                    if isBest {
                        Text("RECORD")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.Colors.coral))
                    }
                }
                Text(Formatters.runDate(run.date))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.inkFaint)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatters.integer(run.score))
                    .font(.display(15))
                    .foregroundStyle(Theme.Colors.ink)
                HStack(spacing: 3) {
                    Image("coin-star").resizable().frame(width: 14, height: 14)
                    Text("+\(Formatters.integer(run.starsCollected)) · \(run.perfectPlacements) perfect")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Colors.inkFaint)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
