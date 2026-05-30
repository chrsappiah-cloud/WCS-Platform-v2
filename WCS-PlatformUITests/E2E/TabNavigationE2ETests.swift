import XCTest

final class TabNavigationE2ETests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAllPrimaryTabsLoadWithoutCrash() {
        let app = XCUIApplication()
        app.launchForE2E()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))

        app.openTab("Discover")
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 8))

        app.openTab("Programs")
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 8))

        app.openTab("Discussion")
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 8))

        app.openTab("Profile")
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 8))
        let accountHeader = app.staticTexts["Account"]
        scrollUntilExists(accountHeader, in: app, maxSwipes: 6)
        XCTAssertTrue(
            accountHeader.waitForExistence(timeout: 12),
            "Profile tab should show account context"
        )

        app.openTab("About")
        XCTAssertTrue(app.navigationBars["About WCS"].waitForExistence(timeout: 10))
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Version")).firstMatch
                .waitForExistence(timeout: 10)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Architecture")).firstMatch
                    .waitForExistence(timeout: 6)
        )
    }

}
