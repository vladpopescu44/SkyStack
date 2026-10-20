import Foundation
import Observation
import SwiftUI

/// Drives one build session: countdown, running, pause and results.
/// Bridges the SpriteKit scene to SwiftUI state.
@MainActor
@Observable
final class GameViewModel {
    enum Phase: Equatable {
        case ready
        case countdown(Int)
        case running
        case paused
        case finished(RunOutcome)
    }

    private(set) var phase: Phase = .ready
    private(set) var hud: GameHUDState
    /// Created lazily in `prepareScene()` so presenting the view is cheap.
    private(set) var scene: TowerScene?
    /// Changes whenever a fresh scene is created so SwiftUI rebuilds the `SpriteView`.
    private(set) var sceneID = UUID()
    /// Incremented when the tower falls so the view can flash.
    private(set) var fallFlashCount = 0
    /// Incremented on every perfect placement so the HUD can pulse.
    private(set) var perfectPulseCount = 0

    private let profileStore: ProfileStore
    private let settings: SettingsStore
    private let haptics: HapticsService
    @ObservationIgnored private var countdownTask: Task<Void, Never>?

    var controlScheme: ControlScheme { settings.controlScheme }
    var builder: BuilderSkin { profileStore.loadout.skin }
    var loadout: BuilderLoadout { profileStore.loadout }
    var bestScore: Int { profileStore.profile.bestScore }
    var bestHeight: Int { profileStore.profile.bestHeight }

    var isScenePaused: Bool {
        if case .paused = phase { return true }
        return false
    }

    var isRunning: Bool { phase == .running }

    init(profileStore: ProfileStore, settings: SettingsStore, haptics: HapticsService) {
        self.profileStore = profileStore
        self.settings = settings
        self.haptics = haptics
        hud = GameHUDState(loadout: profileStore.loadout)
    }

    // MARK: - Scene management

    /// Builds the scene if it does not exist yet. Safe to call repeatedly.
    func prepareScene() {
        guard scene == nil else { return }
        installScene()
    }

    private func installScene() {
        scene?.gameDelegate = nil
        let loadout = profileStore.loadout
        hud = GameHUDState(loadout: loadout)
        let newScene = TowerScene(
            size: CGSize(width: 390, height: 844),
            loadout: loadout,
            acceptsTouchDrops: settings.controlScheme == .tap
        )
        newScene.gameDelegate = self
        scene = newScene
        sceneID = UUID()
    }

    // MARK: - Intents

    /// Starts the 3-2-1 countdown and then the build.
    func beginRun() {
        guard phase == .ready else { return }
        prepareScene()
        haptics.prepare()
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            for value in stride(from: 3, through: 1, by: -1) {
                guard let self, !Task.isCancelled else { return }
                withAnimation(.spring(duration: 0.3)) {
                    self.phase = .countdown(value)
                }
                self.haptics.impact(.light)
                try? await Task.sleep(for: .milliseconds(700))
            }
            guard let self, !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                self.phase = .running
            }
            self.scene?.startRun()
        }
    }

    /// Drops the block from the on-screen button.
    func drop() {
        guard phase == .running else { return }
        scene?.dropBlock()
    }

    func pause() {
        guard phase == .running else { return }
        scene?.setSuspended(true)
        withAnimation(.easeOut(duration: 0.2)) {
            phase = .paused
        }
        haptics.selection()
    }

    func resume() {
        guard phase == .paused else { return }
        scene?.setSuspended(false)
        withAnimation(.easeOut(duration: 0.2)) {
            phase = .running
        }
        haptics.selection()
    }

    /// Pauses automatically when the app leaves the foreground mid-build.
    func handleScenePhaseChange(_ scenePhase: ScenePhase) {
        guard scenePhase != .active else { return }
        if case .countdown = phase {
            countdownTask?.cancel()
            phase = .ready
        } else {
            pause()
        }
    }

    /// Creates a fresh scene with the latest upgrades and returns to the ready state.
    func restart() {
        countdownTask?.cancel()
        installScene()
        withAnimation(.easeOut(duration: 0.25)) {
            phase = .ready
        }
    }

    /// Releases the scene when the game screen goes away.
    func tearDown() {
        countdownTask?.cancel()
        scene?.gameDelegate = nil
        scene = nil
    }
}

// MARK: - TowerSceneDelegate

extension GameViewModel: TowerSceneDelegate {
    func scene(_ scene: TowerScene, didUpdate hud: GameHUDState) {
        guard scene === self.scene else { return }
        self.hud = hud
    }

    func scene(_ scene: TowerScene, didRegister event: GameEvent) {
        guard scene === self.scene else { return }
        switch event {
        case .placed(let perfect):
            if perfect {
                perfectPulseCount += 1
                haptics.impact(.medium)
            } else {
                haptics.impact(.light)
            }
        case .anchored, .lanternLit:
            haptics.notify(.success)
        case .windWarning:
            haptics.impact(.light)
        case .gustStarted, .stormStarted:
            haptics.impact(.medium)
        case .stormEnded:
            haptics.selection()
        case .toppled, .missed:
            fallFlashCount += 1
            haptics.notify(.error)
        }
    }

    func scene(_ scene: TowerScene, didFinishWith summary: RunSummary) {
        guard scene === self.scene else { return }
        let outcome = profileStore.recordRun(summary)
        withAnimation(.spring(duration: 0.45)) {
            phase = .finished(outcome)
        }
        if outcome.isNewBest {
            haptics.notify(.success)
        }
    }
}
