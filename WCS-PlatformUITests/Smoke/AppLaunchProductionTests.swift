import XCTest

/// Release-gate smoke: app must launch and expose primary navigation.
final class AppLaunchProductionTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunch_exposesPrimaryNavigation() {
        let app = XCUIApplication()
        app.launchForE2E()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 12))
        for tab in ["Discover", "Programs", "Discussion", "Profile", "About"] {
            XCTAssertTrue(app.tabBars.buttons[tab].exists, "Missing tab: \(tab)")
        }
    }
}
