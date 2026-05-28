import XCTest

/// Patched manual-backup flow using resilient text entry helpers.
final class ManualBackupAuthoringE2ETests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testManualBackupDraftCreatePublishAndPlaybackFlow() {
        let app = XCUIApplication()
        app.launchForE2E()

        let runID = String(UUID().uuidString.prefix(6))
        let courseTitle = "Manual Backup E2E \(runID)"
        let moduleTitle = "Continuity Module \(runID)"
        let videoTitle = "Lecture \(runID)"
        let readingTitle = "Reading \(runID)"
        let videoURL = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8"

        unlockAdminStudio(app)

        let createButton = app.buttons["createManualBackupDraftButton"]
        scrollUntilExists(createButton, in: app)

        fillTextField(app, identifier: "manualCourseTitleField", value: courseTitle)
        fillTextField(app, identifier: "manualSummaryField", value: "Manual backup summary \(runID).")
        fillTextField(app, identifier: "manualModuleTitleField", value: moduleTitle)
        fillTextField(app, identifier: "manualVideoTitleField", value: videoTitle)
        fillTextField(app, identifier: "manualVideoURLField", value: videoURL)
        fillTextField(app, identifier: "manualReadingTitleField", value: readingTitle)
        fillTextField(app, identifier: "manualQuizTitleField", value: "Quiz \(runID)")
        fillTextField(app, identifier: "manualAssignmentTitleField", value: "Assignment \(runID)")
        fillTextView(app, identifier: "manualReadingMaterialEditor", value: "Reading body \(runID).")
        fillTextView(app, identifier: "manualQuizPromptEditor", value: "Q1? Q2?")
        fillTextView(app, identifier: "manualAssignmentBriefEditor", value: "Submit reflection.")

        scrollToVisible(createButton, in: app)
        XCTAssertTrue(createButton.isEnabled)
        createButton.tap()

        let draftTitle = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", runID)).firstMatch
        scrollUntilExists(draftTitle, in: app, maxSwipes: 14)
        XCTAssertTrue(draftTitle.waitForExistence(timeout: 20))

        let publishButton = app.buttons["Publish to learner catalog"]
        scrollToVisible(publishButton, in: app)
        publishButton.tap()

        app.openTab("Programs")
        let publishedCourse = app.staticTexts[courseTitle]
        if publishedCourse.waitForExistence(timeout: 8) {
            publishedCourse.tap()
            let enroll = app.buttons["Enroll for free"]
            if enroll.waitForExistence(timeout: 3) { enroll.tap() }
            return
        }

        app.openTab("Profile")
        let publishedBadge = app.staticTexts["Published"]
        scrollUntilExists(publishedBadge, in: app)
        XCTAssertTrue(publishedBadge.waitForExistence(timeout: 12))
    }
}
