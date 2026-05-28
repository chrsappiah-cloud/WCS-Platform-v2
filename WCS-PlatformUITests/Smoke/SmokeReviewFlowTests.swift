import XCTest

final class SmokeReviewFlowTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchAndPrimaryTabsAppear() {
        let app = XCUIApplication()
        app.launchForE2E(extraArguments: ["-mockNetwork", "offline"])

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["Discover"].exists)
        XCTAssertTrue(app.tabBars.buttons["Programs"].exists)
        XCTAssertTrue(app.tabBars.buttons["Discussion"].exists)
        XCTAssertTrue(app.tabBars.buttons["Profile"].exists)
    }
}
