import XCTest

/// Mock-auth session path used until dedicated login UI ships.
final class AuthenticationSessionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testProfileShowsAuthenticatedLearnerContext() {
        let app = XCUIApplication()
        app.launchForE2E(extraEnvironment: ["WCS_MOCK_ROLE": "learner"])
        app.openTab("Profile")

        let account = app.staticTexts["Account"]
        scrollUntilExists(account, in: app)
        XCTAssertTrue(
            account.waitForExistence(timeout: 10)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "WCS")).firstMatch
                    .waitForExistence(timeout: 8)
        )
    }
}
