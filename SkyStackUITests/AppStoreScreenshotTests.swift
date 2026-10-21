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
