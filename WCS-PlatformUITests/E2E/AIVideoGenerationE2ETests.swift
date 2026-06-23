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
    func testSimulatorBackendStackActivationShowsSupabaseAndBackups() {
        let app = XCUIApplication()
        app.launchForE2E()
        app.openTab("Profile")

        let checkButton = app.buttons["profileCheckGenerationAPIsButton"]
        scrollUntilExists(checkButton, in: app)
        checkButton.tap()

        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Supabase")).firstMatch
                .waitForExistence(timeout: 25),
            "Generation API check should list Supabase primary backend."
        )
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Cloudflare")).firstMatch
                .waitForExistence(timeout: 10),
            "Generation API check should list Cloudflare backup tier."
        )
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'iCloud' OR label CONTAINS[c] 'icloud'"))
                .firstMatch.waitForExistence(timeout: 10),
            "Generation API check should list iCloud backup tier."
        )
    }

    @MainActor
    func testSimulatorInstructionalLessonTextRendersVideo() throws {
        let app = XCUIApplication()
        app.launchForE2E()
        unlockAdminStudio(app)

        let template = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Professional")
        ).firstMatch
        if template.waitForExistence(timeout: 4) {
            template.tap()
        }

        var productField = app.textFields["adminProductNameField"]
        if !productField.waitForExistence(timeout: 4) {
            scrollUntilExists(app.textFields["Product name"], in: app, maxSwipes: 8)
            productField = app.textFields["Product name"]
        }
        if productField.waitForExistence(timeout: 6) {
            replaceText("Instructional Text Video E2E", in: productField, app: app)
        }

        let generate = app.buttons["adminGenerateDraftButton"]
        scrollUntilExists(generate, in: app, maxSwipes: 16)
        if generate.isEnabled {
            generate.tap()
            _ = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "Publish to learner catalog")
            ).firstMatch.waitForExistence(timeout: 90)
        }

        let instructionalOK = exerciseInstructionalVideoFromLessonText(app, renderDeadlineSeconds: 150)
        let pipelineOK = instructionalOK || exerciseLocalVideoRenderPipeline(
            app,
            productName: nil,
            skipDraftSetup: true,
            renderDeadlineSeconds: 120
        )
        XCTAssertTrue(
            pipelineOK,
            "Lesson text should render to MP4 via Render lesson text or plan → render → compose."
        )
    }

    @MainActor
    func testSimulatorLiveBackendRendersInstructionalLessonVideo() throws {
        let app = XCUIApplication()
        app.launchForE2E(extraEnvironment: liveBackendVideoEnvironment())
        unlockAdminStudio(app)
        createGeneratedDraft(app, productName: "Simulator Live Backend Video Render E2E")

        XCTAssertTrue(
            exerciseLiveBackendInstructionalVideoFromLessonText(app, renderDeadlineSeconds: 180),
            "Simulator E2E must call the live Supabase/OpenAI backend and return a generated lesson video URL."
        )
    }

    /// End-to-end proof that plan → render → compose produces a local MP4 on Simulator (no Apple Intelligence required).
    @MainActor
    func testSimulatorDemonstratesLocalVideoRenderPipeline() throws {
        let app = XCUIApplication()
        app.launchForE2E()
        unlockAdminStudio(app)

        let artifactProduced = exerciseLocalVideoRenderPipeline(
            app,
            productName: "Simulator Video Render E2E",
            draftGenerationTimeout: 90,
            renderDeadlineSeconds: 90
        )
        XCTAssertTrue(
            artifactProduced,
            "Simulator E2E should plan, render, and compose a local MP4 via AVFoundation image-sequence."
        )
    }

    @MainActor
    func testAdminStudioVideoPipelineControls() throws {
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

        var productField = app.textFields["adminProductNameField"]
        if !productField.waitForExistence(timeout: 4) {
            scrollUntilExists(app.textFields["Product name"], in: app, maxSwipes: 8)
            productField = app.textFields["Product name"]
        }
        if productField.waitForExistence(timeout: 6) {
            replaceText("AI Video E2E Operator Program", in: productField, app: app)
        }

        let generate = app.buttons["adminGenerateDraftButton"]
        scrollUntilExists(generate, in: app)
        if generate.isEnabled {
            generate.tap()
            _ = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "Publish to learner catalog")
            ).firstMatch.waitForExistence(timeout: 90)
        }

        let pipelineSucceeded = exerciseLocalVideoRenderPipeline(
            app,
            productName: nil,
            skipDraftSetup: true,
            renderDeadlineSeconds: 90
        )
        XCTAssertTrue(
            pipelineSucceeded,
            "Admin studio scene pipeline should produce planned storyboard status and a local video artifact."
        )
    }

    /// Same local AVFoundation pipeline as Simulator; validates render on real device hardware (no Apple Intelligence required).
    @MainActor
    func testPhysicalDeviceDemonstratesLocalVideoRenderPipeline() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Physical-device local video E2E runs on connected iPhone hardware only.")
        #else
        let app = XCUIApplication()
        app.launchForE2E()
        unlockAdminStudio(app)

        XCTAssertTrue(
            exerciseLocalVideoRenderPipeline(
                app,
                productName: "Physical Device Video Render E2E",
                draftGenerationTimeout: 120,
                renderDeadlineSeconds: 120
            ),
            "Physical iPhone should plan, render, and compose a local MP4 via AVFoundation image-sequence."
        )
        #endif
    }

    @MainActor
    func testTextLessonRendersVideoOnPhysicalDevice() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Text-lesson video render E2E requires a physical iPhone with Apple Intelligence.")
        #else
        let app = XCUIApplication()
        app.launchForE2E(extraEnvironment: ["WCS_UI_TEST_VIDEO_APPROACH": "on_device_experimental"])
        unlockAdminStudio(app)

        XCTAssertTrue(
            exerciseLocalVideoRenderPipeline(
                app,
                productName: "Text Lesson Video Render E2E",
                draftGenerationTimeout: 120,
                renderDeadlineSeconds: 120
            ),
            "Physical device should render video from text lesson content via on-device pipeline."
        )
        #endif
    }

    @MainActor
    func testPhysicalDeviceAppleAndOpenAIVideoPipeline() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Physical-device Apple Intelligence + OpenAI pipeline test runs on iPhone hardware only.")
        #else
        let app = XCUIApplication()
        app.launchForE2E(extraEnvironment: liveBackendVideoEnvironment())
        app.openTab("Profile")

        let checkButton = app.buttons["profileCheckGenerationAPIsButton"]
        scrollUntilExists(checkButton, in: app)
        checkButton.tap()

        let appleFM = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Apple Foundation Models")
        ).firstMatch
        XCTAssertTrue(appleFM.waitForExistence(timeout: 25))

        let openAIBFF = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "OpenAI Sora text-to-video BFF")
        ).firstMatch
        XCTAssertTrue(openAIBFF.waitForExistence(timeout: 10))

        unlockAdminStudio(app)
        createGeneratedDraft(app, productName: "Physical Device Live Backend Video Render E2E")
        XCTAssertTrue(
            exerciseLiveBackendInstructionalVideoFromLessonText(app, renderDeadlineSeconds: 240),
            "Physical device E2E must call the live Supabase/OpenAI backend and return a generated lesson video URL."
        )
        #endif
    }

    // MARK: - Pipeline helpers

    @MainActor
    @discardableResult
    private func exerciseInstructionalVideoFromLessonText(
        _ app: XCUIApplication,
        renderDeadlineSeconds: TimeInterval = 90
    ) -> Bool {
        dismissSystemAlertsIfPresent(app)

        let renderText = app.buttons.matching(identifier: "adminRenderInstructionalVideoButton").firstMatch
        scrollUntilExists(renderText, in: app, maxSwipes: 20)
        guard renderText.waitForExistence(timeout: 12) else { return false }
        let enableDeadline = Date().addingTimeInterval(30)
        while !renderText.isEnabled, Date() < enableDeadline {
            sleep(1)
        }
        if renderText.isEnabled {
            renderText.tap()
        }

        sleep(3)
        let deadline = Date().addingTimeInterval(renderDeadlineSeconds)
        while Date() < deadline {
            dismissSystemAlertsIfPresent(app)
            let status = app.staticTexts["adminVideoPipelineStatusLabel"].firstMatch
            if status.exists {
                let label = status.label.lowercased()
                if label.contains("instructional")
                    || label.contains("lesson text")
                    || pipelineStatusIndicatesRenderedVideo(status.label) {
                    if localVideoArtifactExists(in: app) { return true }
                }
            }
            if localVideoArtifactExists(in: app) { return true }
            sleep(3)
        }
        return localVideoArtifactExists(in: app)
    }

    @MainActor
    @discardableResult
    private func exerciseLiveBackendInstructionalVideoFromLessonText(
        _ app: XCUIApplication,
        renderDeadlineSeconds: TimeInterval = 180
    ) -> Bool {
        dismissSystemAlertsIfPresent(app)

        let renderText = app.buttons.matching(identifier: "adminRenderInstructionalVideoButton").firstMatch
        scrollUntilExists(renderText, in: app, maxSwipes: 20)
        guard renderText.waitForExistence(timeout: 12) else { return false }
        let enableDeadline = Date().addingTimeInterval(30)
        while !renderText.isEnabled, Date() < enableDeadline {
            sleep(1)
        }
        if renderText.isEnabled {
            renderText.tap()
        }

        let deadline = Date().addingTimeInterval(renderDeadlineSeconds)
        var lastStatus = ""
        while Date() < deadline {
            dismissSystemAlertsIfPresent(app)
            let status = app.staticTexts["adminVideoPipelineStatusLabel"].firstMatch
            if status.exists {
                lastStatus = status.label
                if pipelineStatusIndicatesLiveBackendRender(status.label),
                   !pipelineStatusIndicatesFallbackRender(status.label),
                   !pipelineStatusIndicatesBackendFailure(status.label) {
                    return true
                }
                if pipelineStatusIndicatesBackendFailure(status.label) {
                    XCTFail("Live backend video render failed: \(status.label)")
                    return false
                }
            }
            sleep(3)
        }
        if !lastStatus.isEmpty {
            XCTFail("Live backend video render timed out. Last status: \(lastStatus)")
        }
        return false
    }

    /// Plans storyboard, renders first scene, composes lesson; returns true when pipeline status or artifact links confirm MP4 output.
    @MainActor
    @discardableResult
    private func exerciseLocalVideoRenderPipeline(
        _ app: XCUIApplication,
        productName: String?,
        skipDraftSetup: Bool = false,
        draftGenerationTimeout: TimeInterval = 90,
        renderDeadlineSeconds: TimeInterval = 90
    ) -> Bool {
        dismissSystemAlertsIfPresent(app)

        if !skipDraftSetup {
            let template = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "Professional")
            ).firstMatch
            if template.waitForExistence(timeout: 4) {
                template.tap()
            }

            if let productName {
                let productField = app.textFields["adminProductNameField"]
                if !productField.waitForExistence(timeout: 6) {
                    scrollUntilExists(app.textFields["Product name"], in: app, maxSwipes: 8)
                }
                let field = productField.exists ? productField : app.textFields["Product name"]
                if field.waitForExistence(timeout: 8) {
                    replaceText(productName, in: field, app: app)
                }
            }

            let generate = app.buttons["adminGenerateDraftButton"]
            scrollUntilExists(generate, in: app, maxSwipes: 16)
            if generate.isEnabled {
                generate.tap()
                _ = app.staticTexts.matching(
                    NSPredicate(format: "label CONTAINS[c] %@", "Publish to learner catalog")
                ).firstMatch.waitForExistence(timeout: draftGenerationTimeout)
            }
        }

        dismissSystemAlertsIfPresent(app)

        let plan = app.buttons["adminPlanStoryboardButton"]
        scrollUntilExists(plan, in: app, maxSwipes: 20)
        guard plan.waitForExistence(timeout: 15) else {
            XCTFail("Missing storyboard plan button after draft setup.")
            return false
        }

        if plan.isEnabled {
            plan.tap()
        }

        let plannedStatus = app.staticTexts["adminVideoPipelineStatusLabel"].firstMatch
        guard plannedStatus.waitForExistence(timeout: 120) else {
            XCTFail("Storyboard status label did not appear after tapping plan.")
            return false
        }
        let plannedLabel = plannedStatus.label
        guard (plannedLabel as NSString).range(of: "Planned", options: .caseInsensitive).location != NSNotFound else {
            XCTFail("Storyboard plan did not complete. Last status: \(plannedLabel)")
            return false
        }

        dismissSystemAlertsIfPresent(app)

        let render = app.buttons["adminRenderFirstSceneButton"]
        scrollUntilExists(render, in: app, maxSwipes: 12)
        guard render.waitForExistence(timeout: 10) else {
            XCTFail("Missing render-first-scene button after storyboard planning. Last status: \(plannedLabel)")
            return false
        }

        let renderEnableDeadline = Date().addingTimeInterval(45)
        while !render.isEnabled, Date() < renderEnableDeadline {
            sleep(1)
        }
        if render.isEnabled {
            render.tap()
        }

        var renderComplete = false
        var lastStatusLabel = plannedLabel
        let renderDeadline = Date().addingTimeInterval(renderDeadlineSeconds)
        while Date() < renderDeadline {
            dismissSystemAlertsIfPresent(app)
            let status = app.staticTexts["adminVideoPipelineStatusLabel"].firstMatch
            if status.exists {
                lastStatusLabel = status.label
                if pipelineStatusIndicatesRenderedVideo(status.label) {
                    renderComplete = true
                    break
                }
            }
            if localVideoArtifactExists(in: app) {
                renderComplete = true
                break
            }
            sleep(3)
        }
        guard renderComplete else {
            let localLinks = localVideoArtifactExists(in: app)
            XCTFail("Local scene render did not complete before timeout. Last status: \(lastStatusLabel). Local artifact visible: \(localLinks).")
            return false
        }

        dismissSystemAlertsIfPresent(app)

        let compose = app.buttons["adminComposeLessonButton"]
        if compose.exists, compose.isEnabled {
            compose.tap()
            sleep(4)
        }

        if localVideoArtifactExists(in: app) {
            return true
        }

        let composedStatus = app.staticTexts["adminVideoPipelineStatusLabel"].firstMatch
        if composedStatus.exists,
           pipelineStatusIndicatesComposedVideo(composedStatus.label) {
            return true
        }

        XCTFail("Local lesson compose did not expose a composed MP4 artifact. Last status: \(composedStatus.exists ? composedStatus.label : lastStatusLabel)")
        return false
    }

    @MainActor
    private func pipelineStatusIndicatesRenderedVideo(_ label: String) -> Bool {
        let normalized = label.lowercased()
        return normalized.contains("render")
            || normalized.contains(".mp4")
            || normalized.contains("clip")
            || normalized.contains("avfoundation")
            || normalized.contains("image-sequence")
    }

    @MainActor
    private func pipelineStatusIndicatesComposedVideo(_ label: String) -> Bool {
        let normalized = label.lowercased()
        return normalized.contains("composed")
            || normalized.contains(".mp4")
    }

    @MainActor
    private func pipelineStatusIndicatesLiveBackendRender(_ label: String) -> Bool {
        let normalized = label.lowercased()
        return normalized.contains("openai")
            || normalized.contains("sora")
            || normalized.contains("supabase edge")
            || normalized.contains("bff")
    }

    @MainActor
    private func pipelineStatusIndicatesFallbackRender(_ label: String) -> Bool {
        let normalized = label.lowercased()
        if normalized.contains("planned via apple foundation models")
            || normalized.contains("planned via network") {
            return false
        }
        return normalized.contains("avfoundation")
            || normalized.contains("image-sequence")
            || normalized.contains("on-device")
            || normalized.contains("apple image playground")
    }

    @MainActor
    private func pipelineStatusIndicatesBackendFailure(_ label: String) -> Bool {
        let normalized = label.lowercased()
        return normalized.contains("failed")
            || normalized.contains("did not return")
            || normalized.contains("http 401")
            || normalized.contains("http 403")
            || normalized.contains("decode failed")
            || normalized.contains("rejected playbackurl")
    }

    @MainActor
    private func localVideoArtifactExists(in app: XCUIApplication) -> Bool {
        let composedLink = app.links["adminLocalComposedVideoLink"].firstMatch
        let clipLink = app.links["adminLocalImageSequenceClipLink"].firstMatch
        if composedLink.exists || clipLink.exists { return true }
        for _ in 0 ..< 8 {
            app.swipeUp()
            if composedLink.exists || clipLink.exists { return true }
        }
        return composedLink.waitForExistence(timeout: 15)
            || clipLink.waitForExistence(timeout: 5)
    }

    @MainActor
    private func exerciseScenePipelineIfAvailable(_ app: XCUIApplication) {
        _ = exerciseLocalVideoRenderPipeline(
            app,
            productName: nil,
            skipDraftSetup: true,
            renderDeadlineSeconds: 120
        )
    }

    @MainActor
    private func createGeneratedDraft(_ app: XCUIApplication, productName: String) {
        let template = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Professional")
        ).firstMatch
        if template.waitForExistence(timeout: 4) {
            template.tap()
        }

        var productField = app.textFields["adminProductNameField"]
        if !productField.waitForExistence(timeout: 4) {
            scrollUntilExists(app.textFields["Product name"], in: app, maxSwipes: 8)
            productField = app.textFields["Product name"]
        }
        if productField.waitForExistence(timeout: 6) {
            replaceText(productName, in: productField, app: app)
        }

        let generate = app.buttons["adminGenerateDraftButton"]
        scrollUntilExists(generate, in: app, maxSwipes: 16)
        if generate.isEnabled {
            generate.tap()
            _ = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "Publish to learner catalog")
            ).firstMatch.waitForExistence(timeout: 120)
        }
    }

    private func liveBackendVideoEnvironment() -> [String: String] {
        [
            "WCS_UI_TEST_LOCAL_VIDEO_ONLY": "0",
            "WCS_UI_TEST_VIDEO_APPROACH": "hybrid_cloud_native_composition",
            "WCS_E2E_REQUIRE_LIVE_VIDEO_BACKEND": "1",
            "WCS_E2E_ACTIVATE_BACKEND": "1"
        ]
    }

    @MainActor
    private func dismissSystemAlertsIfPresent(_ app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.buttons["Close"].exists {
            springboard.buttons["Close"].tap()
        }
        if app.buttons["Not Now"].exists {
            app.buttons["Not Now"].tap()
        }
    }
}
