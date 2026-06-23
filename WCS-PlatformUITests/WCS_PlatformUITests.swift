//
//  WCS_PlatformUITests.swift
//  WCS-PlatformUITests
//

import XCTest

final class WCS_PlatformUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launchForE2E()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Discover"].exists)
        XCTAssertTrue(app.tabBars.buttons["Programs"].exists)
        XCTAssertTrue(app.tabBars.buttons["Discussion"].exists)
        XCTAssertTrue(app.tabBars.buttons["Profile"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("Launch performance metric is validated on simulator CI runners.")
        #else
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
        #endif
    }

    @MainActor
    func testPlayFromDataToDecisionModule() throws {
        let app = XCUIApplication()
        app.launchForE2E()

        app.openTab("Programs")

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
        scrollUntilExists(moduleLabel, in: app)
        XCTAssertTrue(moduleLabel.waitForExistence(timeout: 30))
        moduleLabel.tap()

        let lessonTitle = "From data to decision"
        let lessonLabel = app.staticTexts[lessonTitle]
        XCTAssertTrue(lessonLabel.waitForExistence(timeout: 10))
        lessonLabel.tap()

        let pauseButton = app.buttons["Pause"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 20))

        let timeline = app.staticTexts["videoTimelineLabel"]
        XCTAssertTrue(timeline.waitForExistence(timeout: 10))
        let firstValue = timeline.label
        sleep(3)
        let secondValue = timeline.label
        XCTAssertNotEqual(firstValue, secondValue, "Timeline did not advance; video may not be playing.")
    }
}
