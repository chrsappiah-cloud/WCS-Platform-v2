import XCTest

final class ReviewCriticalPathUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOfflineLaunchAndProgramsNavigation() {
        let app = XCUIApplication()
        app.launchForE2E(extraArguments: ["-mockNetwork", "offline", "-seedEmptyDatabase"])

        XCTAssertTrue(app.tabBars.buttons["Programs"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Programs"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 8))
    }

    @MainActor
    func testDeniedPermissionModeStillAllowsNavigation() {
        let app = XCUIApplication()
        app.launchForE2E(extraArguments: ["-mockPermissions", "deniedCamera"])

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        app.tabBars.buttons["Profile"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 8))
    }
}
