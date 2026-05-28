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
            accountHeader.waitForExistence(timeout: 12)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Premium")).firstMatch
                    .waitForExistence(timeout: 6),
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

    @MainActor
    func testProfilePrimaryActionsAreReachable() {
        let app = XCUIApplication()
        app.launchForE2E()
        app.openTab("Profile")

        let membership = app.buttons["Membership, subscriptions, and payouts"]
        if !membership.waitForExistence(timeout: 4) {
            scrollUntilExists(app.staticTexts["Membership, subscriptions, and payouts"], in: app)
            app.staticTexts["Membership, subscriptions, and payouts"].tap()
        } else {
            scrollUntilExists(membership, in: app)
            membership.tap()
        }
        XCTAssertTrue(app.navigationBars["Membership & payouts"].waitForExistence(timeout: 8))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let studio = app.buttons["WCS AI Course Generation"]
        scrollUntilExists(studio, in: app)
        studio.tap()
        XCTAssertTrue(
            app.staticTexts["adminStudioConsoleTitle"].waitForExistence(timeout: 12)
                || app.staticTexts["WCS AI Course Generation Studio"].waitForExistence(timeout: 6)
        )
    }
}
