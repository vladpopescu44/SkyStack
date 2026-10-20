import XCTest

/// End-to-end flows through the real interface.
/// The app launches with `--uitesting`, which uses an in-memory save and seeds 1,000 stars.
private extension XCUIElement {
    /// Waits until the element can be tapped (pages in a carousel animate into place).
    func waitForHittable(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}

final class SkyStackUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func waitFor(_ identifier: String, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element(identifier).waitForExistence(timeout: timeout), "Expected \(identifier) to appear", file: file, line: line)
    }

    /// Waits until the "Starting in N" overlay has disappeared, i.e. the build is live.
    private func waitForCountdownToFinish(file: StaticString = #filePath, line: UInt = #line) {
        let countdown = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Starting in")).firstMatch
        XCTAssertTrue(countdown.waitForExistence(timeout: 5), "Countdown never started", file: file, line: line)
        XCTAssertTrue(countdown.waitForNonExistence(timeout: 8), "Countdown never finished", file: file, line: line)
        // Let the HUD fade-in complete before interacting.
        usleep(400_000)
    }

    /// Taps the pause button by coordinate: the animated scene underneath makes
    /// XCUITest's hittability snapshots slow and occasionally stale.
    private func tapPause(_ pause: XCUIElement) {
        XCTAssertTrue(pause.waitForExistence(timeout: 3))
        pause.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    /// Returns to the skyline through the dock.
    private func goHome() {
        element("tab.skyline").tap()
    }

    // MARK: - Home

    @MainActor
    func testHomeShowsCoreElements() {
        waitFor("home.screen")
        XCTAssertTrue(element("home.play").exists)
        XCTAssertTrue(element("home.workshop").exists)
        XCTAssertTrue(element("home.builders").exists)
        XCTAssertTrue(element("home.records").exists)
        XCTAssertTrue(element("home.howToPlay").exists)
        XCTAssertTrue(element("home.settings").exists)
        XCTAssertTrue(element("home.starBalance").exists)
    }

    // MARK: - Navigation

    @MainActor
    func testNavigatesToEveryScreenAndBack() {
        waitFor("home.screen")

        element("home.workshop").tap()
        waitFor("workshop.screen")
        goHome()
        waitFor("home.screen")

        element("home.builders").tap()
        waitFor("builders.screen")
        goHome()
        waitFor("home.screen")

        element("home.records").tap()
        waitFor("records.screen")
        XCTAssertTrue(element("records.empty").waitForExistence(timeout: 3))
        goHome()
        waitFor("home.screen")

        element("home.howToPlay").tap()
        waitFor("howToPlay.screen")
        // Page through the illustrated guide to the end, then finish it.
        for _ in 0..<7 {
            let next = element("howToPlay.next")
            XCTAssertTrue(next.waitForExistence(timeout: 3))
            next.tap()
        }
        element("howToPlay.continue").tap()
        waitFor("home.screen")

        element("home.settings").tap()
        waitFor("settings.screen")
        XCTAssertTrue(element("settings.haptics").exists)
        XCTAssertTrue(element("settings.controls").exists)
        XCTAssertTrue(element("settings.reset").exists)
        element("settings.close").tap()
        waitFor("home.screen")
    }

    // MARK: - Workshop

    @MainActor
    func testWorkshopPurchaseShowsConfirmation() {
        waitFor("home.screen")
        element("home.workshop").tap()
        waitFor("workshop.screen")

        let precision = element("workshop.upgrade.precision")
        XCTAssertTrue(precision.waitForExistence(timeout: 3))
        precision.tap()

        XCTAssertTrue(app.staticTexts["Steady Hands upgraded to level 1."].waitForExistence(timeout: 3))
        // The button now advertises the next level's price.
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Upgrade Steady Hands for 100")).firstMatch.waitForExistence(timeout: 3))
    }

    @MainActor
    func testWorkshopRejectsUnaffordableUpgrade() {
        waitFor("home.screen")
        element("home.workshop").tap()
        waitFor("workshop.screen")

        // Ballast level 1 costs 110; spend 985 of the 1,000 seeded stars on Star Charm first.
        let charm = element("workshop.upgrade.charm")
        XCTAssertTrue(charm.waitForExistence(timeout: 3))
        for level in 1...4 {
            charm.tap()
            XCTAssertTrue(app.staticTexts["Star Charm upgraded to level \(level)."].waitForExistence(timeout: 3))
            // Wait for the toast to clear so the next tap is not swallowed by animation.
            _ = app.staticTexts["Star Charm upgraded to level \(level)."].waitForNonExistence(timeout: 4)
        }
        element("workshop.upgrade.ballast").tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "You need")).firstMatch.waitForExistence(timeout: 3))
    }

    // MARK: - Builders

    @MainActor
    func testUnlockingBuilderEquipsIt() {
        waitFor("home.screen")
        element("home.builders").tap()
        waitFor("builders.screen")

        // Jump to Kite with the roster, then hire them from their page.
        element("builders.thumb.kite").tap()
        let unlock = element("builders.action.kite")
        XCTAssertTrue(unlock.waitForExistence(timeout: 3))
        _ = unlock.waitForHittable(timeout: 3)
        unlock.tap()

        XCTAssertTrue(app.staticTexts["Kite unlocked and equipped."].waitForExistence(timeout: 3))
        let card = element("builders.card.kite")
        XCTAssertTrue(card.staticTexts["EQUIPPED"].waitForExistence(timeout: 3))
    }

    // MARK: - Settings

    @MainActor
    func testResetProgressFlow() {
        waitFor("home.screen")
        element("home.settings").tap()
        waitFor("settings.screen")

        element("settings.reset").tap()
        let confirm = app.buttons["Reset everything"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()

        XCTAssertTrue(app.staticTexts["Progress reset. The sky is clear again."].waitForExistence(timeout: 3))
    }

    // MARK: - Game

    @MainActor
    func testStartPauseResumeAndQuitBuild() {
        waitFor("home.screen")
        element("home.play").tap()
        waitFor("game.screen")

        let start = element("game.start")
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        // The 3-2-1 countdown must finish before the HUD becomes interactive.
        waitForCountdownToFinish()
        let pause = element("game.pause")
        tapPause(pause)
        attachScreenshot(named: "after first pause tap")
        waitFor("game.pausedOverlay")

        // While paused the simulation must stand still.
        let heightBefore = element("game.height").label
        let scoreBefore = element("game.score").label
        sleep(2)
        XCTAssertEqual(element("game.height").label, heightBefore, "Height changed while paused")
        XCTAssertEqual(element("game.score").label, scoreBefore, "Score changed while paused")

        element("game.resume").tap()
        XCTAssertTrue(element("game.pausedOverlay").waitForNonExistence(timeout: 3))

        tapPause(pause)
        waitFor("game.pausedOverlay")
        element("game.quit").tap()

        waitFor("home.screen")
    }

    /// Dropping a few blocks by tapping the playfield raises the height counter.
    @MainActor
    func testTappingDropsBlocks() {
        waitFor("home.screen")
        element("home.play").tap()
        waitFor("game.screen")
        element("game.start").tap()
        waitForCountdownToFinish()

        let playfield = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        for _ in 0..<3 {
            playfield.tap()
            usleep(350_000)
        }
        let height = element("game.height")
        XCTAssertTrue(height.waitForExistence(timeout: 3))
        // Either the tower grew, or the block missed and the results card appeared: both prove the drop worked.
        let grew = height.label != "0"
        let finished = element("game.gameOverOverlay").waitForExistence(timeout: 3)
        XCTAssertTrue(grew || finished, "Tapping the playfield did not drop a block")
    }

    /// The settings sheet opens from the skyline and closes back to it.
    @MainActor
    func testSettingsSheetChangesControls() {
        waitFor("home.screen")
        element("home.settings").tap()
        waitFor("settings.screen")
        app.buttons["Drop button"].tap()
        element("settings.close").tap()
        waitFor("home.screen")

        element("home.play").tap()
        waitFor("game.screen")
        element("game.start").tap()
        waitForCountdownToFinish()
        XCTAssertTrue(element("game.drop").waitForExistence(timeout: 3), "Drop button scheme was not applied")
        element("game.drop").tap()
        tapPause(element("game.pause"))
        waitFor("game.pausedOverlay")
        element("game.quit").tap()
        waitFor("home.screen")
    }

    /// Without touches the tower must not grow: blocks only drop on a tap or the DROP button.
    @MainActor
    func testBlocksNeverDropWithoutInput() {
        waitFor("home.screen")
        element("home.play").tap()
        waitFor("game.screen")
        element("game.start").tap()
        waitForCountdownToFinish()
        sleep(6)
        XCTAssertEqual(element("game.height").label, "0", "A block dropped without any input")
        XCTAssertFalse(element("game.gameOverOverlay").exists)
        tapPause(element("game.pause"))
        waitFor("game.pausedOverlay")
        element("game.quit").tap()
        waitFor("home.screen")
    }

    // MARK: - iPad

    /// iPad supports every orientation, so the base and the game must stay usable in landscape.
    @MainActor
    func testLandscapeLayoutOnPad() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "Landscape is only supported on iPad")
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }

        waitFor("home.screen")
        // Give the rotation animation time to settle before checking hit targets.
        XCTAssertTrue(element("home.play").waitForHittable(timeout: 5), "BUILD is not tappable in landscape")
        XCTAssertTrue(element("home.workshop").waitForHittable(timeout: 3))
        attachScreenshot(named: "iPad landscape home")

        element("home.workshop").tap()
        waitFor("workshop.screen")
        XCTAssertTrue(element("workshop.upgrade.precision").isHittable)
        attachScreenshot(named: "iPad landscape workshop")
        element("home.builders").tap()
        waitFor("builders.screen")
        attachScreenshot(named: "iPad landscape crew")
        element("home.records").tap()
        waitFor("records.screen")
        attachScreenshot(named: "iPad landscape logbook")
        goHome()
        waitFor("home.screen")

        element("home.play").tap()
        waitFor("game.screen")
        let start = element("game.start")
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(start.isHittable)
        attachScreenshot(named: "iPad landscape game ready")
        start.tap()

        waitForCountdownToFinish()
        attachScreenshot(named: "iPad landscape game running")
        tapPause(element("game.pause"))
        waitFor("game.pausedOverlay")
        element("game.quit").tap()
        waitFor("home.screen")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
