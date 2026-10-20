import SpriteKit
import SwiftUI

/// Full-screen play view: SpriteKit scene underneath, SwiftUI HUD and overlays on top.
struct GameView: View {
    @State private var viewModel: GameViewModel
    let onQuit: (Route?) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var fallFlashOpacity: Double = 0

    init(viewModel: GameViewModel, onQuit: @escaping (Route?) -> Void) {
        self.viewModel = viewModel
        self.onQuit = onQuit
    }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            if let scene = viewModel.scene {
                SpriteView(scene: scene, isPaused: viewModel.isScenePaused, preferredFramesPerSecond: 60)
                    .id(viewModel.sceneID)
                    .ignoresSafeArea()
            }

            fallVignette

            GameHUDView(
                hud: viewModel.hud,
                perfectPulse: viewModel.perfectPulseCount,
                isVisible: viewModel.isRunning || viewModel.isScenePaused,
                onPause: viewModel.pause
            )

            if viewModel.controlScheme == .button, viewModel.isRunning {
                DropControl(onDrop: viewModel.drop)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            overlays
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Game.screen)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear { viewModel.prepareScene() }
        .onDisappear { viewModel.tearDown() }
        .onChange(of: scenePhase) { _, newPhase in
            viewModel.handleScenePhaseChange(newPhase)
        }
        .onChange(of: viewModel.fallFlashCount) { _, _ in
            fallFlashOpacity = 1
            withAnimation(.easeOut(duration: 0.6)) {
                fallFlashOpacity = 0
            }
        }
    }

    private var fallVignette: some View {
        RadialGradient(
            colors: [.clear, Theme.Colors.coral.opacity(0.7)],
            center: .center,
            startRadius: 120,
            endRadius: 520
        )
        .ignoresSafeArea()
        .opacity(fallFlashOpacity)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var overlays: some View {
        switch viewModel.phase {
        case .ready:
            ReadyOverlay(
                builder: viewModel.builder,
                loadout: viewModel.loadout,
                bestScore: viewModel.bestScore,
                bestHeight: viewModel.bestHeight,
                controlScheme: viewModel.controlScheme,
                onStart: viewModel.beginRun,
                onQuit: { onQuit(nil) }
            )
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        case .countdown(let value):
            CountdownOverlay(value: value)
                .transition(.opacity)
        case .running:
            EmptyView()
        case .paused:
            PauseOverlay(
                height: viewModel.hud.height,
                score: viewModel.hud.score,
                onResume: viewModel.resume,
                onRestart: viewModel.restart,
                onQuit: { onQuit(nil) }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        case .finished(let outcome):
            GameOverView(
                outcome: outcome,
                onPlayAgain: viewModel.restart,
                onWorkshop: { onQuit(.workshop) },
                onQuit: { onQuit(nil) }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// The big drop button for the button control scheme.
private struct DropControl: View {
    let onDrop: () -> Void

    var body: some View {
        VStack {
            Spacer()
            Button(action: onDrop) {
                Label("DROP", systemImage: "arrow.down.to.line")
                    .font(.display(22, weight: .black))
                    .tracking(2)
                    .frame(maxWidth: 360)
            }
            .buttonStyle(SkyButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
            .accessibilityLabel("Drop block")
            .accessibilityIdentifier(AccessibilityID.Game.dropButton)
        }
    }
}
