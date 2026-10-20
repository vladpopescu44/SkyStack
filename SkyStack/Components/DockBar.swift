import SwiftUI

/// The four sections of the app, switched from the dock.
enum AppTab: String, CaseIterable, Identifiable {
    case skyline, workshop, crew, logbook

    var id: String { rawValue }

    var title: String {
        switch self {
        case .skyline: "Skyline"
        case .workshop: "Workshop"
        case .crew: "Crew"
        case .logbook: "Logbook"
        }
    }

    var accessibilityID: String {
        switch self {
        case .skyline: AccessibilityID.Dock.skyline
        case .workshop: AccessibilityID.Home.workshopButton
        case .crew: AccessibilityID.Home.buildersButton
        case .logbook: AccessibilityID.Home.recordsButton
        }
    }
}

/// Bottom dock: two tabs, a raised BUILD block in the middle, two more tabs.
struct DockBar: View {
    @Binding var selection: AppTab
    let equipped: BuilderSkin
    let onBuild: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            item(.skyline)
            item(.workshop)
            buildButton
            item(.crew)
            item(.logbook)
        }
        .padding(.horizontal, 8)
        .frame(height: Theme.Metrics.dockHeight)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.white)
                .shadow(color: Theme.Colors.ink.opacity(0.22), radius: 16, y: 6)
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    private func item(_ tab: AppTab) -> some View {
        let isSelected = selection == tab
        return Button {
            withAnimation(.spring(duration: 0.3)) { selection = tab }
        } label: {
            VStack(spacing: 3) {
                icon(for: tab)
                    .frame(width: 30, height: 30)
                    .scaleEffect(isSelected ? 1.12 : 0.92)
                    .saturation(isSelected ? 1 : 0.35)
                    .opacity(isSelected ? 1 : 0.75)
                Text(tab.title)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(isSelected ? Theme.Colors.ink : Theme.Colors.inkFaint)
                Capsule()
                    .fill(isSelected ? Theme.Colors.coral : .clear)
                    .frame(width: 16, height: 3)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(tab.accessibilityID)
    }

    @ViewBuilder
    private func icon(for tab: AppTab) -> some View {
        switch tab {
        case .skyline:
            VStack(spacing: 1.5) {
                Image(equipped.blockAsset(forFloor: 0)).resizable().frame(width: 16, height: 6)
                Image(equipped.blockAsset(forFloor: 1)).resizable().frame(width: 20, height: 6)
                Image(equipped.blockAsset(forFloor: 2)).resizable().frame(width: 24, height: 7)
                Image("block-base").resizable().frame(width: 26, height: 7)
            }
        case .workshop:
            Image("upgrade-foundation").resizable().scaledToFit()
        case .crew:
            Image(equipped.portraitAsset).resizable().scaledToFit()
        case .logbook:
            ZStack {
                Image("stamp-earned").resizable().scaledToFit()
                Image(systemName: "book.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
            }
        }
    }

    private var buildButton: some View {
        Button(action: onBuild) {
            VStack(spacing: 0) {
                Image(systemName: "arrow.up.to.line")
                    .font(.system(size: 20, weight: .black))
                Text("BUILD")
                    .font(.display(13, weight: .black))
                    .tracking(1)
            }
            .foregroundStyle(.white)
            .frame(width: 74, height: 74)
            .background {
                Circle()
                    .fill(LinearGradient(colors: [Theme.Colors.sun, Theme.Colors.coral], startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().strokeBorder(.white, lineWidth: 4))
                    .shadow(color: Theme.Colors.coral.opacity(0.5), radius: 10, y: 5)
            }
        }
        .buttonStyle(PressSquashStyle())
        .offset(y: -20)
        .frame(width: 84)
        .accessibilityLabel("Build")
        .accessibilityIdentifier(AccessibilityID.Home.playButton)
    }
}

/// Squash-on-press feedback for custom-drawn buttons.
struct PressSquashStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(x: configuration.isPressed ? 1.06 : 1, y: configuration.isPressed ? 0.92 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.5), value: configuration.isPressed)
    }
}
