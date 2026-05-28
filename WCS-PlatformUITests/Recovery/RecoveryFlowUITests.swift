import XCTest

final class RecoveryFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testExpiredTokenSeedStillLoadsAppShell() {
        let app = XCUIApplication()
        app.launchForE2E(extraArguments: ["-seedExpiredToken"])

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["Discover"].exists)
    }

    @MainActor
    func testStoreKitProductsFailureModeDoesNotCrashApp() {
        let app = XCUIApplication()
        app.launchForE2E(extraArguments: ["-mockStoreKit", "productsFailure"])

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        app.tabBars.buttons["Profile"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 8))
    }
}
