//
//  WCS_PlatformUITests.swift
//  WCS-PlatformUITests
//
//  Created by Christopher Appiah-Thompson  on 25/4/2026.
//

import XCTest

final class WCS_PlatformUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Discover"].exists)
        XCTAssertTrue(app.tabBars.buttons["Programs"].exists)
        XCTAssertTrue(app.tabBars.buttons["Discussion"].exists)
        XCTAssertTrue(app.tabBars.buttons["Profile"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testPlayFromDataToDecisionModule() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        app.tabBars.buttons["Programs"].tap()

        let courseTitle = "Decision Science Essentials"
        let courseTitleLabel = app.staticTexts[courseTitle]
        XCTAssertTrue(courseTitleLabel.waitForExistence(timeout: 10))
        courseTitleLabel.tap()

        let enrollButton = app.buttons["Enroll for free"]
        if enrollButton.waitForExistence(timeout: 3) {
            enrollButton.tap()
        }

        let moduleTitle = "Module 1 — Decisions under uncertainty"
        let moduleLabel = app.staticTexts[moduleTitle]
        XCTAssertTrue(moduleLabel.waitForExistence(timeout: 10))
        moduleLabel.tap()

        let lessonTitle = "From data to decision"
        let lessonLabel = app.staticTexts[lessonTitle]
        XCTAssertTrue(lessonLabel.waitForExistence(timeout: 10))
        lessonLabel.tap()

        // Auto-play should flip the transport control to Pause when playback starts.
        let pauseButton = app.buttons["Pause"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 20))

        // Confirm actual playback progression (not only UI control state).
        let timeline = app.staticTexts["videoTimelineLabel"]
        XCTAssertTrue(timeline.waitForExistence(timeout: 10))
        let firstValue = timeline.label
        sleep(3)
        let secondValue = timeline.label
        XCTAssertNotEqual(firstValue, secondValue, "Timeline did not advance; video may not be playing.")
    }

    @MainActor
    func testManualBackupDraftCreatePublishAndPlaybackFlow() throws {
        let app = XCUIApplication()
        app.launch()

        let courseTitle = "Manual Backup iPhone Validation"
        let moduleTitle = "Manual Continuity Module"
        let videoTitle = "Manual continuity lecture"
        let readingTitle = "Manual continuity reading"

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8))
        app.tabBars.buttons["Profile"].tap()

        let studioLink = app.buttons["WCS AI Course Generation"]
        scrollUntilExists(studioLink, in: app)
        XCTAssertTrue(studioLink.waitForExistence(timeout: 12))
        studioLink.tap()

        let accessField = app.secureTextFields["Admin access code"]
        if accessField.waitForExistence(timeout: 5) {
            accessField.tap()
            accessField.typeText("wcs-admin-2026")
            app.buttons["Unlock Studio"].tap()
        }

        let manualSectionButton = app.buttons["createManualBackupDraftButton"]
        XCTAssertTrue(manualSectionButton.waitForExistence(timeout: 12))

        fillTextField(app, identifier: "manualCourseTitleField", value: courseTitle)
        fillTextField(app, identifier: "manualSummaryField", value: "Manual fallback package for device validation.")
        fillTextField(app, identifier: "manualModuleTitleField", value: moduleTitle)
        fillTextField(app, identifier: "manualVideoTitleField", value: videoTitle)
        fillTextField(app, identifier: "manualVideoURLField", value: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")
        fillTextField(app, identifier: "manualReadingTitleField", value: readingTitle)
        fillTextField(app, identifier: "manualQuizTitleField", value: "Manual continuity quiz")
        fillTextField(app, identifier: "manualAssignmentTitleField", value: "Manual continuity assignment")
        fillTextView(app, identifier: "manualReadingMaterialEditor", value: "Operator handbook and fallback notes.")
        fillTextView(app, identifier: "manualQuizPromptEditor", value: "Q1. What keeps learning continuity online?")
        fillTextView(app, identifier: "manualAssignmentBriefEditor", value: "Submit a continuity execution checklist.")

        scrollToElementIfNeeded(manualSectionButton, in: app)
        XCTAssertTrue(manualSectionButton.isEnabled)
        manualSectionButton.tap()

        let draftTitle = app.staticTexts[courseTitle]
        XCTAssertTrue(draftTitle.waitForExistence(timeout: 10))
        let publishButton = app.buttons["Publish to learner catalog"]
        scrollToElementIfNeeded(publishButton, in: app)
        XCTAssertTrue(publishButton.waitForExistence(timeout: 8))
        publishButton.tap()

        app.tabBars.buttons["Programs"].tap()
        let publishedCourse = app.staticTexts[courseTitle]
        XCTAssertTrue(publishedCourse.waitForExistence(timeout: 15))
        publishedCourse.tap()

        let enrollButton = app.buttons["Enroll for free"]
        if enrollButton.waitForExistence(timeout: 3) {
            enrollButton.tap()
        }

        let moduleLabel = app.staticTexts[moduleTitle]
        XCTAssertTrue(moduleLabel.waitForExistence(timeout: 10))
        moduleLabel.tap()

        let videoLabel = app.staticTexts[videoTitle]
        XCTAssertTrue(videoLabel.waitForExistence(timeout: 10))
        videoLabel.tap()

        let pauseButton = app.buttons["Pause"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 20))
        let timeline = app.staticTexts["videoTimelineLabel"]
        XCTAssertTrue(timeline.waitForExistence(timeout: 10))
        let t0 = timeline.label
        sleep(3)
        let t1 = timeline.label
        XCTAssertNotEqual(t0, t1, "Manual backup video timeline did not advance.")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let readingLabel = app.staticTexts[readingTitle]
        XCTAssertTrue(readingLabel.waitForExistence(timeout: 8))
    }

    private func fillTextField(_ app: XCUIApplication, identifier: String, value: String) {
        let field = app.textFields[identifier]
        scrollToElementIfNeeded(field, in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.press(forDuration: 1.0)
        if app.menuItems["Select All"].exists {
            app.menuItems["Select All"].tap()
            app.keys["delete"].tap()
        }
        field.typeText(value)
    }

    private func fillTextView(_ app: XCUIApplication, identifier: String, value: String) {
        let editor = app.textViews[identifier]
        scrollToElementIfNeeded(editor, in: app)
        replaceText(in: editor, value: value, app: app)
    }

    private func replaceText(in element: XCUIElement, value: String, app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        element.tap()
        element.press(forDuration: 1.0)
        if app.menuItems["Select All"].exists {
            app.menuItems["Select All"].tap()
            if app.keys["delete"].exists { app.keys["delete"].tap() }
        }
        app.typeText(value)
    }

    private func scrollToElementIfNeeded(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) {
        if element.exists && element.isHittable { return }
        for _ in 0 ..< maxSwipes where !element.isHittable {
            app.swipeUp()
        }
        if !element.isHittable {
            for _ in 0 ..< maxSwipes where !element.isHittable {
                app.swipeDown()
            }
        }
    }

    private func scrollUntilExists(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 10) {
        if element.exists { return }
        for _ in 0 ..< maxSwipes where !element.exists {
            app.swipeUp()
        }
        if !element.exists {
            for _ in 0 ..< maxSwipes where !element.exists {
                app.swipeDown()
            }
        }
    }
}
