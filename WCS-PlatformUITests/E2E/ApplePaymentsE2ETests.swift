import XCTest

final class ApplePaymentsE2ETests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMembershipHubLoadsPlansAndStoreKitSection() {
        let app = XCUIApplication()
        app.launchForE2E()
        openMembershipPaymentsHub(app)

        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Free")).firstMatch
                .waitForExistence(timeout: 12)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Individual")).firstMatch
                    .waitForExistence(timeout: 12),
            "Expected subscription plans in membership hub"
        )

        XCTAssertTrue(
            app.staticTexts["Apple subscriptions (StoreKit)"].waitForExistence(timeout: 12),
            "StoreKit section should be visible in membership hub"
        )
    }

    @MainActor
    func testStoreKitPurchaseFlowIsWired() {
        let app = XCUIApplication()
        app.launchForE2E()
        openMembershipPaymentsHub(app)

        let loading = app.otherElements["storeKitProductsLoading"]
        if loading.exists {
            _ = loading.waitForNonExistence(timeout: 20)
        }

        let purchaseButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "storeKitPurchaseButton_")
        ).firstMatch

        if purchaseButton.waitForExistence(timeout: 15) {
            purchaseButton.tap()
            dismissStoreKitSheetIfPresent(app)
            let message = app.staticTexts["storeKitPurchaseMessage"]
            XCTAssertTrue(
                message.waitForExistence(timeout: 20),
                "Expected StoreKit purchase result message after tapping product"
            )
            return
        }

        let storeKitGuidance = app.staticTexts.matching(
            NSPredicate(
                format: "label CONTAINS[c] 'WCSAppleSubscriptionProductIDs' OR label CONTAINS[c] 'Loading Apple products' OR label CONTAINS[c] 'purchase'"
            )
        ).firstMatch
        XCTAssertTrue(
            storeKitGuidance.waitForExistence(timeout: 12),
            "StoreKit section should show products, loading state, or configuration guidance"
        )
    }

    @MainActor
    private func dismissStoreKitSheetIfPresent(_ app: XCUIApplication) {
        let cancel = app.buttons["Cancel"]
        if cancel.waitForExistence(timeout: 4) {
            cancel.tap()
            return
        }
        let close = app.buttons["Close"]
        if close.waitForExistence(timeout: 2) {
            close.tap()
        }
    }
}
