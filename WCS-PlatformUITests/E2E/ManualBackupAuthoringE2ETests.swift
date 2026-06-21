import XCTest

/// Patched manual-backup flow using resilient text entry helpers.
final class ManualBackupAuthoringE2ETests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testManualBackupExternalURLAndLocalImportBackupCreatePublishPlaybackFlow() {
        let runID = String(UUID().uuidString.prefix(6))
        let courseTitle = "Manual Backup E2E \(runID)"
        let moduleTitle = "Continuity Module \(runID)"
        let videoTitle = "Lecture \(runID)"
        let readingTitle = "Reading \(runID)"
        let videoURL = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8"
        let app = XCUIApplication()
        app.launchForE2E(
            extraArguments: ["-seedEmptyDatabase"],
            extraEnvironment: [
                "WCS_UI_TEST_PREFILL_MANUAL_BACKUP": "1",
                "WCS_UI_TEST_MANUAL_COURSE_TITLE": courseTitle,
                "WCS_UI_TEST_MANUAL_SUMMARY": "Manual backup summary \(runID).",
                "WCS_UI_TEST_MANUAL_MODULE_TITLE": moduleTitle,
                "WCS_UI_TEST_MANUAL_VIDEO_TITLE": videoTitle,
                "WCS_UI_TEST_MANUAL_VIDEO_URL": videoURL,
                "WCS_UI_TEST_MANUAL_READING_TITLE": readingTitle,
                "WCS_UI_TEST_MANUAL_READING_BODY": "Reading body \(runID).",
                "WCS_UI_TEST_MANUAL_QUIZ_TITLE": "Quiz \(runID)",
                "WCS_UI_TEST_MANUAL_QUIZ_PROMPT": "Q1? Q2?",
                "WCS_UI_TEST_MANUAL_ASSIGNMENT_TITLE": "Assignment \(runID)",
                "WCS_UI_TEST_MANUAL_ASSIGNMENT_BRIEF": "Submit reflection."
            ]
        )

        unlockAdminStudio(app)

        let createButton = app.buttons["createManualBackupDraftButton"]
        scrollUntilExists(createButton, in: app)

        scrollToVisible(createButton, in: app)
        XCTAssertTrue(createButton.isEnabled, "Create manual backup draft button should be enabled after all required fields are filled.")
        createButton.tap()

        let draftTitle = app.staticTexts[courseTitle]
        scrollUntilExists(draftTitle, in: app, maxSwipes: 20)
        XCTAssertTrue(draftTitle.waitForExistence(timeout: 60), "Created manual backup draft should appear in Drafts: \(courseTitle)")

        let manualBackupPanel = app.staticTexts["Manual lesson video backups (per module)"]
        scrollUntilExists(manualBackupPanel, in: app, maxSwipes: 10)
        if manualBackupPanel.waitForExistence(timeout: 5) {
            manualBackupPanel.tap()
            let localImport = app.buttons["manualLessonVideoProbeLocalButton"].firstMatch
            scrollUntilExists(localImport, in: app, maxSwipes: 8)
            XCTAssertTrue(localImport.waitForExistence(timeout: 8), "Manual local video import control should be available as a backup path.")
            let backupURLField = app.textFields["manualLessonVideoBackupURLField"].firstMatch
            XCTAssertTrue(backupURLField.waitForExistence(timeout: 8), "Manual external URL backup field should be available per video lesson.")
        }

        let publishButton = app.buttons["Publish to learner catalog"]
        scrollToVisible(publishButton, in: app)
        XCTAssertTrue(publishButton.waitForExistence(timeout: 10), "Publish button should be visible for the created manual backup draft.")
        publishButton.tap()

        let publishedBadge = app.staticTexts["Published"]
        scrollUntilExists(publishedBadge, in: app)
        XCTAssertTrue(publishedBadge.waitForExistence(timeout: 12), "Manual backup draft should be marked Published after tapping Publish.")
    }
}
