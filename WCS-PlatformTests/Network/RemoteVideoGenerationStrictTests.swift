import Foundation
import Testing
@testable import WCS_Platform

struct RemoteVideoGenerationStrictTests {
    private var strictModeEnabled: Bool {
        ProcessInfo.processInfo.environment["WCS_STRICT_REMOTE_VIDEO_TESTS"] == "1"
    }

    @Test
    func remoteLessonTextToVideoPayloadIncludesCleanSourceScript() throws {
        let request = RemoteLessonTextToVideoRequest(
            courseId: "course-1",
            courseTitle: "Plant Science",
            moduleId: "module-1",
            moduleTitle: "Energy",
            lessonId: "lesson-1",
            lessonTitle: "Photosynthesis",
            lessonNotes: "machine:ignored\nPlants convert sunlight into glucose.",
            sourceScript: "Plants convert sunlight into glucose.",
            targetAudience: "Students",
            level: "High school",
            textToVideoPrompt: "Render a clear instructional scene.",
            sourceReferences: ["curriculum"],
            providerBackendHint: "sora",
            clientAppVersion: "1.0",
            storyboard: nil,
            pipelineMode: .sceneOrchestrationV1,
            sceneBreakdownProvider: nil
        )

        let data = try JSONEncoder().encode(request)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"sourceScript\":\"Plants convert sunlight into glucose.\""))
        #expect(json.contains("\"providerBackendHint\":\"sora\""))
    }

    @Test
    func generatedLessonVideoPolicyRejectsSampleAndCompanionURLs() throws {
        let sample = try #require(URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"))
        let appleSample = try #require(URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8"))
        let youtube = try #require(URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
        let signed = try #require(URL(string: "https://cdn.example.com/rendered/lesson.mp4?token=abc"))
        let local = URL(fileURLWithPath: "/tmp/rendered-lesson.mp4")

        #expect(LessonVideoSafetyPolicy.validateGeneratedLessonVideoURL(sample) != nil)
        #expect(LessonVideoSafetyPolicy.validateGeneratedLessonVideoURL(appleSample) != nil)
        #expect(LessonVideoSafetyPolicy.validateGeneratedLessonVideoURL(youtube) != nil)
        #expect(LessonVideoSafetyPolicy.validateGeneratedLessonVideoURL(signed) == nil)
        #expect(LessonVideoSafetyPolicy.validateGeneratedLessonVideoURL(local) == nil)
    }

    @Test
    func remoteTextToVideoConfiguration_isPresentWhenStrictModeEnabled() {
        guard strictModeEnabled else { return }
        #expect(
            LessonVideoGenerationSettings.remoteTextToVideoEndpointURL != nil,
            "Strict remote mode requires WCSLessonTextToVideoEndpoint (https)."
        )
    }

    @Test
    func generatedLessonVideos_doNotUseSampleFallbackURLsInStrictMode() async throws {
        guard strictModeEnabled else { return }

        await AdminCourseDraftStore.shared.clearAll()
        await MockLearningStore.shared.deleteBlockedAICourses()

        let previousAdminMode = UserDefaults.standard.bool(forKey: "wcs.mockAdminMode")
        defer { UserDefaults.standard.set(previousAdminMode, forKey: "wcs.mockAdminMode") }
        UserDefaults.standard.set(true, forKey: "wcs.mockAdminMode")

        let draft = try await AdminCourseDraftStore.shared.createManualBackupDraft(
            createdBy: "admin@wcs",
            accessTier: .freePublic,
            courseTitle: "Strict Remote Video Gate",
            summary: "Validate remote text-to-video path without fallback samples.",
            moduleTitle: "Strict Gate Module",
            videoTitle: "Strict Gate Video",
            videoURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8",
            readingTitle: "Reading",
            readingMaterial: "Body.",
            quizTitle: "Quiz",
            quizPrompt: "Q1",
            assignmentTitle: "Assignment",
            assignmentBrief: "Brief."
        )

        await MockLearningStore.shared.regenerateVideoAssets(for: draft, clearCache: true)
        guard let course = await MockLearningStore.shared.snapshotCourse(draft.id) else {
            Issue.record("Strict remote gate could not load generated course snapshot.")
            return
        }

        let videoURLs = course.modules
            .flatMap(\.lessons)
            .filter { $0.type == .video }
            .compactMap(\.videoURL)

        #expect(!videoURLs.isEmpty, "Strict remote gate expected at least one video URL.")
        #expect(videoURLs.allSatisfy { $0.lowercased().hasPrefix("https://") })
        #expect(videoURLs.allSatisfy { !$0.contains("storage.googleapis.com/gtv-videos-bucket/sample/") })
        #expect(videoURLs.allSatisfy { !$0.contains("youtube.com/watch") })
    }
}
