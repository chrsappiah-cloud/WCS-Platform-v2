import XCTest

final class SmokeReviewFlowTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchAndPrimaryTabsAppear() {
        let app = XCUIApplication()
        app.launchForE2E(extraArguments: ["-mockNetwork", "offline"])

        app.openTab("Discover")
        app.openTab("Programs")
        app.openTab("Discussion")
        app.openTab("Profile")
    }
}
