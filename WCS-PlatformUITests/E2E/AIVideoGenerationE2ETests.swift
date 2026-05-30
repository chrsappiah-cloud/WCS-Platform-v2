import XCTest

final class AIVideoGenerationE2ETests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testGenerationAPICheckFromProfile() {
        let app = XCUIApplication()
        app.launchForE2E()
        app.openTab("Profile")

        let checkButton = app.buttons["profileCheckGenerationAPIsButton"]
        scrollUntilExists(checkButton, in: app)
        checkButton.tap()

        let status = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Generation API check")
        ).firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 20))
    }

    @MainActor
    func testAdminStudioVideoPipelineControls() throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("Admin studio pipeline stress test is run on simulator CI.")
        #endif
        let app = XCUIApplication()
        app.launchForE2E()
        unlockAdminStudio(app)

        let refreshJobs = app.buttons["Refresh job list"]
        if refreshJobs.waitForExistence(timeout: 4) {
            scrollUntilExists(refreshJobs, in: app)
            refreshJobs.tap()
        }

        let template = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Professional")
        ).firstMatch
        if template.waitForExistence(timeout: 4) {
            template.tap()
        }

        let productName = app.textFields["Product name"]
        if productName.waitForExistence(timeout: 4) {
            replaceText("AI Video E2E Operator Program", in: productName, app: app)
        }

        let generate = app.buttons["adminGenerateDraftButton"]
        scrollUntilExists(generate, in: app)
        if generate.isEnabled {
            generate.tap()
            _ = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "Publish to learner catalog")
            ).firstMatch.waitForExistence(timeout: 90)
        }

        exerciseScenePipelineIfAvailable(app)
    }

    @MainActor
    private func exerciseScenePipelineIfAvailable(_ app: XCUIApplication) {
        let plan = app.buttons["adminPlanStoryboardButton"]
        scrollUntilExists(plan, in: app, maxSwipes: 16)
        guard plan.exists else { return }

        if plan.isEnabled {
            plan.tap()
            sleep(2)
        }

        let render = app.buttons["adminRenderFirstSceneButton"]
        if render.exists, render.isEnabled {
            render.tap()
            sleep(2)
        }

        let compose = app.buttons["adminComposeLessonButton"]
        if compose.exists, compose.isEnabled {
            compose.tap()
            sleep(2)
        }

        let preview = app.buttons["adminPreviewSceneButton"]
        if preview.exists, preview.isEnabled {
            preview.tap()
        }
    }
}
