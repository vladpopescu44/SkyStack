import XCTest

/// Generates deterministic, full-resolution App Store screenshots on the selected simulator.
final class AppStoreScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(element("home.screen").waitForExistence(timeout: 8))
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testCaptureStoreScreens() {
        capture("01-skyline")

        element("home.workshop").tap()
        XCTAssertTrue(element("workshop.screen").waitForExistence(timeout: 5))
        capture("02-workshop")

        element("home.builders").tap()
        XCTAssertTrue(element("builders.screen").waitForExistence(timeout: 5))
        capture("03-crew")

        element("home.play").tap()
        XCTAssertTrue(element("game.screen").waitForExistence(timeout: 5))
        capture("04-ready")
    }

    /// Captures six additional, genuinely different app states so each device has
    /// a complete ten-image App Store gallery without duplicating screens.
    @MainActor
    func testCaptureAdditionalStoreScreens() {
        element("home.records").tap()
        XCTAssertTrue(element("records.screen").waitForExistence(timeout: 5))
        capture("05-logbook")

        element("tab.skyline").tap()
        XCTAssertTrue(element("home.screen").waitForExistence(timeout: 5))
        element("home.settings").tap()
        XCTAssertTrue(element("settings.screen").waitForExistence(timeout: 5))
        capture("06-settings")
        element("settings.close").tap()

        XCTAssertTrue(element("home.screen").waitForExistence(timeout: 5))
        element("home.howToPlay").tap()
        XCTAssertTrue(element("howToPlay.screen").waitForExistence(timeout: 5))
        capture("07-guide-drop")
        element("howToPlay.next").tap()
        XCTAssertTrue(app.staticTexts["Overhang breaks off"].waitForExistence(timeout: 3))
        element("howToPlay.next").tap()
        XCTAssertTrue(app.staticTexts["Read the wind"].waitForExistence(timeout: 3))
        capture("08-guide-wind")
        element("howToPlay.close").tap()

        XCTAssertTrue(element("home.screen").waitForExistence(timeout: 5))
        element("home.play").tap()
        XCTAssertTrue(element("game.screen").waitForExistence(timeout: 5))
        element("game.start").tap()

        let countdown = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Starting in"))
            .firstMatch
        XCTAssertTrue(countdown.waitForExistence(timeout: 5))
        XCTAssertTrue(countdown.waitForNonExistence(timeout: 8))
        usleep(500_000)
        capture("09-building")

        let pause = element("game.pause")
        XCTAssertTrue(pause.waitForExistence(timeout: 3))
        pause.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(element("game.pausedOverlay").waitForExistence(timeout: 5))
        capture("10-paused")
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
