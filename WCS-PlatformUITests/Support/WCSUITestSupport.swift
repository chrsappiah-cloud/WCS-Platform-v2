import UIKit
import XCTest

enum WCSUITestLaunch {
    static let uiTestMode = "-uiTestMode"
    static let adminAccessCodeKey = "WCS_UI_TEST_ADMIN_ACCESS_CODE"
    static let mockRoleKey = "WCS_MOCK_ROLE"
}

extension XCUIApplication {
    func launchForE2E(extraArguments: [String] = [], extraEnvironment: [String: String] = [:]) {
        launchArguments += [WCSUITestLaunch.uiTestMode]
        launchEnvironment[WCSUITestLaunch.adminAccessCodeKey] = launchEnvironment[WCSUITestLaunch.adminAccessCodeKey] ?? "wcs-admin-2026"
        launchEnvironment["WCS_UI_TEST_LOCAL_VIDEO_ONLY"] = launchEnvironment["WCS_UI_TEST_LOCAL_VIDEO_ONLY"] ?? "1"
        launchEnvironment["WCS_UI_TEST_VIDEO_APPROACH"] = launchEnvironment["WCS_UI_TEST_VIDEO_APPROACH"] ?? "image_sequence_animation"
        launchEnvironment["WCS_E2E_ACTIVATE_BACKEND"] = launchEnvironment["WCS_E2E_ACTIVATE_BACKEND"] ?? "1"
        launchArguments.append(contentsOf: extraArguments)
        for (key, value) in extraEnvironment {
            launchEnvironment[key] = value
        }
        launch()
    }

    func openTab(_ title: String, timeout: TimeInterval = 8) {
        let deadline = Date().addingTimeInterval(timeout)

        func candidate() -> XCUIElement? {
            let tabBarButton = tabBars.buttons[title].firstMatch
            if tabBarButton.exists { return tabBarButton }

            let directButton = buttons[title].firstMatch
            if directButton.exists { return directButton }

            let selectedPredicate = NSPredicate(format: "label == %@ OR identifier == %@", title, title)
            let anyMatch = descendants(matching: .any).matching(selectedPredicate).firstMatch
            if anyMatch.exists { return anyMatch }

            return nil
        }

        while Date() < deadline {
            if let tab = candidate() {
                tab.tap()
                return
            }

            let more = tabBars.buttons["More"]
            if more.exists {
                more.tap()
                if let tab = candidate() {
                    tab.tap()
                    return
                }
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        XCTFail("Missing tab \(title)")
    }
}

extension XCTestCase {
    func fillTextField(
        _ app: XCUIApplication,
        identifier: String,
        value: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let field = app.textFields[identifier]
        scrollToVisible(field, in: app)
        replaceText(value, in: field, app: app, file: file, line: line)
    }

    func fillSecureField(
        _ app: XCUIApplication,
        identifier: String,
        value: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let field = app.secureTextFields[identifier]
        scrollToVisible(field, in: app)
        replaceText(value, in: field, app: app, file: file, line: line)
    }

    func fillTextView(
        _ app: XCUIApplication,
        identifier: String,
        value: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let editor = app.textViews[identifier]
        scrollToVisible(editor, in: app)
        replaceText(value, in: editor, app: app, file: file, line: line)
    }

    func replaceText(
        _ value: String,
        in element: XCUIElement,
        app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 8), file: file, line: line)
        dismissKeyboard(app)

        for attempt in 0 ..< 4 {
            scrollToVisible(element, in: app)
            element.tap()
            if waitForKeyboard(app, timeout: 2) {
                break
            }
            if attempt == 3 {
                element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            usleep(300_000)
        }

        clearFocusedField(element, app: app)
        pasteText(value, into: element, app: app, file: file, line: line)
    }

    func unlockAdminStudio(_ app: XCUIApplication, code: String = "wcs-admin-2026") {
        app.openTab("Profile")
        var studio = app.descendants(matching: .any).matching(identifier: "profileAICourseGenerationLink").firstMatch
        scrollUntilExists(studio, in: app)
        studio = app.descendants(matching: .any).matching(identifier: "profileAICourseGenerationLink").firstMatch
        if !studio.exists {
            studio = app.buttons["WCS AI Course Generation"]
            scrollUntilExists(studio, in: app)
        }
        if studio.exists {
            studio.tap()
        } else {
            XCTFail("Unable to find WCS AI Course Generation profile link.")
        }

        scrollUntilExists(app.staticTexts["adminStudioConsoleTitle"], in: app, maxSwipes: 16)
        if app.staticTexts["adminStudioConsoleTitle"].waitForExistence(timeout: 3)
            || app.staticTexts["WCS AI Course Generation Studio"].waitForExistence(timeout: 3) {
            return
        }

        let accessField = app.secureTextFields["Admin access code"]
        if accessField.waitForExistence(timeout: 6) {
            replaceText(code, in: accessField, app: app)
            let verifyButton = app.buttons["Verify Admin Access"]
            if verifyButton.waitForExistence(timeout: 2) {
                verifyButton.tap()
            } else {
                app.buttons["Unlock Studio"].tap()
            }
        }

        scrollUntilExists(app.staticTexts["adminStudioConsoleTitle"], in: app, maxSwipes: 16)
        XCTAssertTrue(
            app.staticTexts["adminStudioConsoleTitle"].waitForExistence(timeout: 15)
                || app.staticTexts["WCS AI Course Generation Studio"].waitForExistence(timeout: 3),
            "Admin studio did not unlock"
        )
    }

    func dismissKeyboard(_ app: XCUIApplication) {
        if app.keyboards.buttons["Done"].exists {
            app.keyboards.buttons["Done"].tap()
            return
        }
        if app.keyboards.buttons["Return"].exists {
            app.keyboards.buttons["Return"].tap()
            return
        }
        if app.keyboards.count > 0 {
            app.swipeDown()
        }
    }

    private func waitForKeyboard(_ app: XCUIApplication, timeout: TimeInterval) -> Bool {
        app.keyboards.firstMatch.waitForExistence(timeout: timeout)
    }

    private func clearFocusedField(_ element: XCUIElement, app: XCUIApplication) {
        element.press(forDuration: 1.0)
        if app.menuItems["Select All"].waitForExistence(timeout: 1) {
            app.menuItems["Select All"].tap()
            // Next typeText replaces the selection; avoid tapping the delete key (often off-screen in UI tests).
            return
        }
        let existing = (element.value as? String) ?? ""
        guard !existing.isEmpty else { return }
        for _ in 0 ..< min(existing.count + 4, 120) {
            element.typeText(XCUIKeyboardKey.delete.rawValue)
        }
    }

    private func pasteText(
        _ value: String,
        into element: XCUIElement,
        app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        element.tap()
        usleep(400_000)

        if app.menuItems["Paste"].waitForExistence(timeout: 1) {
            UIPasteboard.general.string = value
            app.menuItems["Paste"].tap()
            return
        }

        typeTextInChunks(value, into: element, app: app)
        XCTAssertFalse(value.isEmpty, file: file, line: line)
    }

    private func typeTextInChunks(_ value: String, into element: XCUIElement, app: XCUIApplication) {
        let chunkSize = 12
        var start = value.startIndex
        while start < value.endIndex {
            let end = value.index(start, offsetBy: chunkSize, limitedBy: value.endIndex) ?? value.endIndex
            element.typeText(String(value[start ..< end]))
            start = end
            usleep(80_000)
        }
        dismissKeyboard(app)
    }

    func scrollToVisible(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 10) {
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

    func scrollUntilExists(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 12) {
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
