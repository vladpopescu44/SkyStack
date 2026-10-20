import Foundation

/// Accessibility identifiers shared between the app and its UI tests.
/// Keep the raw values in sync with `SkyStackUITests`.
enum AccessibilityID {
    enum Home {
        static let screen = "home.screen"
        static let playButton = "home.play"
        static let workshopButton = "home.workshop"
        static let buildersButton = "home.builders"
        static let recordsButton = "home.records"
        static let howToPlayButton = "home.howToPlay"
        static let settingsButton = "home.settings"
        static let starBalance = "home.starBalance"
    }

    enum Game {
        static let screen = "game.screen"
        static let startButton = "game.start"
        static let pauseButton = "game.pause"
        static let resumeButton = "game.resume"
        static let restartButton = "game.restart"
        static let quitButton = "game.quit"
        static let heightLabel = "game.height"
        static let scoreLabel = "game.score"
        static let dropButton = "game.drop"
        static let pausedOverlay = "game.pausedOverlay"
        static let gameOverOverlay = "game.gameOverOverlay"
    }

    enum Workshop {
        static let screen = "workshop.screen"
        static func upgradeButton(_ id: String) -> String { "workshop.upgrade.\(id)" }
    }

    enum Builders {
        static let screen = "builders.screen"
        static func card(_ id: String) -> String { "builders.card.\(id)" }
        static func action(_ id: String) -> String { "builders.action.\(id)" }
    }

    enum Records {
        static let screen = "records.screen"
        static let emptyState = "records.empty"
    }

    enum Settings {
        static let screen = "settings.screen"
        static let hapticsToggle = "settings.haptics"
        static let controlPicker = "settings.controls"
        static let resetButton = "settings.reset"
    }

    enum HowToPlay {
        static let screen = "howToPlay.screen"
        static let continueButton = "howToPlay.continue"
    }
}
