import SwiftUI

/// Hosts the dock and its four sections, and presents the game, the tutorial and settings.
struct RootView: View {
    let dependencies: AppDependencies

    @State private var tab: AppTab = .skyline
    @State private var isPlaying = false
    @State private var isOnboardingPresented = false
    @State private var shouldPlayAfterOnboarding = false
    @State private var isGuidePresented = false
    @State private var isSettingsPresented = false
    @State private var tabAfterGame: AppTab?

    var body: some View {
        ZStack(alignment: .bottom) {
            section
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaPadding(.bottom, Theme.Metrics.dockHeight + 30)
                .id(tab)
                .transition(.opacity)

            DockBar(selection: $tab, equipped: dependencies.profileStore.profile.selectedBuilder, onBuild: requestPlay)
        }
        .animation(.easeOut(duration: 0.2), value: tab)
        .tint(Theme.Colors.sky)
        .preferredColorScheme(.light)
        .fullScreenCover(isPresented: $isPlaying, onDismiss: handleGameDismissed) {
            GameView(
                viewModel: GameViewModel(
                    profileStore: dependencies.profileStore,
                    settings: dependencies.settings,
                    haptics: dependencies.haptics
                ),
                onQuit: { next in
                    tabAfterGame = next
                    isPlaying = false
                }
            )
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(
                viewModel: SettingsViewModel(
                    settings: dependencies.settings,
                    store: dependencies.profileStore,
                    haptics: dependencies.haptics
                ),
                onClose: { isSettingsPresented = false }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .background {
            // Separate host views keep the two full-screen guides from competing with the game cover.
            Color.clear
                .fullScreenCover(isPresented: $isOnboardingPresented, onDismiss: handleOnboardingDismissed) {
                    HowToPlayView(mode: .onboarding) {
                        dependencies.settings.hasSeenHowToPlay = true
                        shouldPlayAfterOnboarding = true
                        isOnboardingPresented = false
                    }
                }
            Color.clear
                .fullScreenCover(isPresented: $isGuidePresented) {
                    HowToPlayView(mode: .reference) { isGuidePresented = false }
                }
        }
        .environment(dependencies.profileStore)
        .environment(dependencies.settings)
    }

    @ViewBuilder
    private var section: some View {
        switch tab {
        case .skyline:
            SkylineView(
                onShowGuide: { isGuidePresented = true },
                onShowSettings: { isSettingsPresented = true },
                onOpenCrew: { tab = .crew }
            )
        case .workshop:
            WorkshopView(viewModel: WorkshopViewModel(store: dependencies.profileStore, haptics: dependencies.haptics))
        case .crew:
            CrewView(viewModel: BuildersViewModel(store: dependencies.profileStore, haptics: dependencies.haptics))
        case .logbook:
            LogbookView()
        }
    }

    private func requestPlay() {
        if dependencies.settings.hasSeenHowToPlay {
            isPlaying = true
        } else {
            isOnboardingPresented = true
        }
    }

    private func handleOnboardingDismissed() {
        guard shouldPlayAfterOnboarding else { return }
        shouldPlayAfterOnboarding = false
        isPlaying = true
    }

    /// Leaving the game lands on the skyline (where the record tower lives) unless a section was requested.
    private func handleGameDismissed() {
        tab = tabAfterGame ?? .skyline
        tabAfterGame = nil
    }
}
