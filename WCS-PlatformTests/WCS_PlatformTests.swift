//
//  WCS_PlatformTests.swift
//  WCS-PlatformTests
//
//  Created by Christopher Appiah-Thompson  on 25/4/2026.
//

import Testing
import Foundation
@testable import WCS_Platform

struct WCS_PlatformTests {

    @Test func publishedAIDraftHasStructuredBriefAndReport() async throws {
        await MockLearningStore.shared.deleteBlockedAICourses()
        await MockLearningStore.shared.publishDraftToCatalog(makeDraftForTests(
            title: "AI Business Operator",
            summary: "AI-generated draft for administrators only. Includes module video lessons plus course materials from open-source references for internal review before publication.",
            outcomePrefix: "Build real AI operating workflows",
            includeFindings: true
        ))

        let courses = await MockLearningStore.shared.snapshotCourses(forPremiumUser: true)
        guard let published = courses.first(where: { $0.title == "AI Business Operator" }) else {
            #expect(Bool(false), "Published draft course should exist in catalog.")
            return
        }

        #expect(published.description.contains("Course design goals:"))
        #expect(published.description.contains("Module overview:"))
        #expect(published.description.contains("Learning outcomes:"))
        #expect(published.courseReport != nil)
        #expect((published.courseReport?.learningOutcomes.count ?? 0) > 0)
    }

    @Test func publishGuardBlocksQuestionStyleOutput() async throws {
        let store = AdminCourseDraftStore(generator: StubQuestionGenerator())
        let prompt = """
        Build a WCS AI Course Generation blueprint using a retrieval-plan-generate workflow.
        Product name: What is AI?
        Ideal learner: general users
        Transformation promise: understand AI
        Offer stack: modules and quizzes
        Launch angle: awareness
        Additional curriculum and brand notes: none
        """

        let generated = try await store.generate(prompt: prompt, createdBy: "admin@wcs", accessTier: .freePublic)
        #expect(generated.title.lowercased().contains("what is"))

        await #expect(throws: Error.self) {
            try await store.markPublished(generated.id)
        }
    }

    @Test func publishedDraftVideoLessonsResolvePlaybackURLs() async throws {
        await MockLearningStore.shared.deleteBlockedAICourses()
        let draft = makeDraftForTests(
            title: "AI Video Rendering Validation",
            summary: "Validate that all module video lessons resolve playback URLs.",
            outcomePrefix: "Render playable module videos",
            includeFindings: true
        )

        await MockLearningStore.shared.publishDraftToCatalog(draft)

        // Video assets are applied asynchronously; poll for completion.
        let deadline = Date().addingTimeInterval(8)
        var latestCourse: Course?
        while Date() < deadline {
            if let course = await MockLearningStore.shared.snapshotCourse(draft.id) {
                latestCourse = course
                let videoLessons = course.modules.flatMap(\.lessons).filter { $0.type == .video }
                let allResolved = !videoLessons.isEmpty && videoLessons.allSatisfy {
                    guard let url = $0.videoURL else { return false }
                    return url.hasPrefix("http")
                }
                if allResolved { break }
            }
            try await Task.sleep(nanoseconds: 300_000_000)
        }

        guard let course = latestCourse else {
            #expect(Bool(false), "Published course should be retrievable for video validation.")
            return
        }

        let videoLessons = course.modules.flatMap(\.lessons).filter { $0.type == .video }
        #expect(!videoLessons.isEmpty, "Expected at least one video lesson in generated module structure.")
        #expect(videoLessons.allSatisfy { ($0.videoURL ?? "").hasPrefix("http") })
        #expect(videoLessons.allSatisfy { ($0.subtitle ?? "").isEmpty == false })
    }

    @Test func generatedVideoAssetsContainModuleMediaMetadata() async throws {
        let draft = makeDraftForTests(
            title: "AI Media Metadata Validation",
            summary: "Validate script segments, YouTube companion hints, and audio readiness metadata.",
            outcomePrefix: "Verify media metadata quality",
            includeFindings: false
        )
        let generator = MockAIVideoGenerator()
        let generated = await generator.generateVideoAssets(for: draft) { _ in }

        #expect(!generated.isEmpty, "Expected generated video assets for video lessons.")

        for asset in generated.values {
            #expect((asset.youtubeCompanionURL ?? "").contains("youtube.com/results"))
            #expect(!(asset.youtubeSearchKeywords ?? []).isEmpty)
            #expect(!(asset.moduleScriptSegments ?? []).isEmpty)
            #expect((asset.tutorialNarrationText ?? "").contains("World Class Scholars"))
            #expect(!(asset.microphoneChecklist ?? []).isEmpty)
            #expect((asset.audioSystemStatus ?? "").isEmpty == false)
            #expect(
                (asset.openAIRecommendedPipeline ?? []).contains(where: { $0.contains("/v1/videos") })
            )
            #expect(
                (asset.openAIRecommendedPipeline ?? []).contains(where: { $0.contains("/v1/audio/speech") })
            )
        }
    }

    @Test func scriptLinesCoverVideoLessonsInOrder() async throws {
        await MockLearningStore.shared.deleteBlockedAICourses()
        let draft = makeDraftForTests(
            title: "Script Line Coverage",
            summary: "Ensure pipeline sees video lessons.",
            outcomePrefix: "Learn",
            includeFindings: false
        )
        await MockLearningStore.shared.publishDraftToCatalog(draft)

        guard let course = await MockLearningStore.shared.snapshotCourse(draft.id) else {
            Issue.record("Expected published course.")
            return
        }

        let lines = ModuleVideoDiscoveryPipeline.scriptLines(from: course)
        let videoLessonCount = course.modules.flatMap(\.lessons).filter { $0.type == .video }.count
        #expect(lines.count == videoLessonCount)
        #expect(!lines.isEmpty)
        #expect(lines.first?.youTubeSearchQuery.contains(course.title) == true)
    }

    @Test func youTubeQuerySynthesis_isFastAtScale() {
        let course = Course(
            id: UUID(),
            title: "World Class Scholars Bootcamp",
            subtitle: nil,
            description: "Learning outcomes: a | b",
            thumbnailURL: "https://example.com/t.jpg",
            coverURL: nil,
            durationSeconds: 3600,
            price: nil,
            isEnrolled: true,
            isOwned: true,
            isUnlockedBySubscription: false,
            rating: nil,
            reviewCount: 0,
            organizationName: "WCS",
            level: "Beginner",
            effortDescription: nil,
            spokenLanguages: ["en"],
            modules: [
                Module(
                    id: UUID(),
                    title: "Foundations",
                    description: nil,
                    order: 0,
                    isAvailable: true,
                    isUnlocked: true,
                    lessons: [
                        Lesson(
                            id: UUID(),
                            title: "Welcome",
                            subtitle: "Orientation",
                            type: .video,
                            videoURL: "https://example.com/v.mp4",
                            durationSeconds: 120,
                            isCompleted: false,
                            isAvailable: true,
                            isUnlocked: true,
                            reading: nil,
                            quiz: nil,
                            assignment: nil
                        )
                    ]
                )
            ],
            courseReport: nil
        )

        let lines = ModuleVideoDiscoveryPipeline.scriptLines(from: course)
        let iterations = 3_000
        let t0 = CFAbsoluteTimeGetCurrent()
        for _ in 0 ..< iterations {
            for line in lines {
                _ = line.youTubeSearchQuery
            }
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - t0
        #expect(elapsed < 0.2, "Local query synthesis should stay interactive; saw \(elapsed)s")
    }

    @Test func youTubeSearch_singleProbe_skipsWithoutKey() async throws {
        guard YouTubeSearchAPIClient.resolveAPIKey() != nil else {
            return
        }
        let t0 = CFAbsoluteTimeGetCurrent()
        let page: YouTubeSearchPage
        do {
            page = try await YouTubeSearchAPIClient.searchVideos(
                query: "online learning platform lecture",
                maxResults: 2
            )
        } catch let YouTubeAPIError.httpStatus(code, message)
            where code == 400 && (message?.localizedCaseInsensitiveContains("API key not valid") ?? false) {
            // Treat invalid scheme key as "missing key" in CI/dev environments.
            return
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - t0
        #expect(elapsed < 25)
        #expect(page.items.count <= 2)
    }

    @Test func manualBackupDraft_publishesWithManualVideoAndLearningArtifacts() async throws {
        await AdminCourseDraftStore.shared.clearAll()
        await MockLearningStore.shared.deleteBlockedAICourses()

        let manualVideoURL = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8"
        let draft = await AdminCourseDraftStore.shared.createManualBackupDraft(
            createdBy: "admin@wcs",
            accessTier: .freePublic,
            courseTitle: "Manual Continuity Course",
            summary: "Manual backup package for automation outages.",
            moduleTitle: "Continuity Module",
            videoTitle: "Manual lecture upload",
            videoURL: manualVideoURL,
            readingTitle: "Manual reading pack",
            readingMaterial: "Core references and facilitator notes.",
            quizTitle: "Manual quiz set",
            quizPrompt: "Q1/Q2/Q3",
            assignmentTitle: "Manual assignment brief",
            assignmentBrief: "Submit an implementation memo."
        )

        try await AdminCourseDraftStore.shared.markPublished(draft.id)
        guard let published = await MockLearningStore.shared.snapshotCourse(draft.id) else {
            Issue.record("Expected published manual backup course.")
            return
        }

        let lessons = published.modules.flatMap(\.lessons)
        #expect(lessons.contains(where: { $0.type == .video }))
        #expect(lessons.contains(where: { $0.type == .reading }))
        #expect(lessons.contains(where: { $0.type == .quiz }))
        #expect(lessons.contains(where: { $0.type == .assignment }))
        #expect(lessons.first(where: { $0.type == .video })?.videoURL == manualVideoURL)
    }

    @Test func crossrefDecode_handlesEmptyPayload() throws {
        let data = Data(#"{"message":{"items":[]}}"#.utf8)
        let works = try CrossrefWorksAPIClient.decodeWorks(from: data)
        #expect(works.isEmpty)
    }

    @Test func youTubeDecode_handlesMinimalPayload() throws {
        let data = Data(
            #"{"items":[{"id":{"videoId":"dQw4w9WgXcQ"},"snippet":{"title":"Learning Demo","thumbnails":{"medium":{"url":"https://img.youtube.com/vi/dQw4w9WgXcQ/mqdefault.jpg"}}}}],"nextPageToken":"abc"}"#.utf8
        )
        let page = try YouTubeSearchAPIClient.decodePage(from: data)
        #expect(page.items.count == 1)
        #expect(page.items[0].videoID == "dQw4w9WgXcQ")
    }

    @Test func outboundLinkPolicy_blocksUnknownHosts() {
        let blocked = OutboundLinkPolicy.validatedURL("https://evil.example/phish", category: .social)
        #expect(blocked == nil)
    }

}

private struct StubQuestionGenerator: AICourseGenerating {
    func generateDraft(prompt: String, createdBy: String, accessTier: AdminCourseAccessTier) async throws -> AdminCourseDraft {
        makeDraftForTests(
            title: "What is AI?",
            summary: "Question-style generated text.",
            outcomePrefix: "Understand AI basics",
            includeFindings: false
        )
    }
}

private func makeDraftForTests(
    title: String,
    summary: String,
    outcomePrefix: String,
    includeFindings: Bool
) -> AdminCourseDraft {
    let lessonVideo = AdminLessonDraft(
        id: UUID(),
        title: "Foundations video",
        kind: .video,
        durationMinutes: 20,
        notes: "Intro"
    )
    let lessonQuiz = AdminLessonDraft(
        id: UUID(),
        title: "Knowledge check",
        kind: .quiz,
        durationMinutes: 10,
        notes: "Quiz"
    )
    let lessonAssignment = AdminLessonDraft(
        id: UUID(),
        title: "Applied assignment",
        kind: .assignment,
        durationMinutes: 30,
        notes: "Assignment"
    )
    let module = AdminModuleDraft(
        id: UUID(),
        title: "Module 1",
        goals: ["Goal 1", "Goal 2"],
        lessons: [lessonVideo, lessonQuiz, lessonAssignment]
    )
    let findings: [AICourseReportFinding] = includeFindings ? [
        AICourseReportFinding(
            id: UUID(),
            title: "Delivery model fit",
            detail: "Weekly cohort is recommended.",
            confidence: 0.88
        )
    ] : []

    return AdminCourseDraft(
        id: UUID(),
        createdAt: Date(),
        updatedAt: Date(),
        createdBy: "admin@wcs",
        title: title,
        summary: summary,
        targetAudience: "Professionals",
        level: "Intermediate",
        durationWeeks: 8,
        outcomes: [
            "\(outcomePrefix) through structured implementation.",
            "Apply concepts to real workflows.",
            "Produce a capstone artifact."
        ],
        modules: [module],
        status: .readyForReview,
        accessTier: .freePublic,
        sourceReferences: ["OpenAlex API"],
        promotionalCopy: ["Launch your next learning milestone."],
        funnelPreview: nil,
        reasoningReport: AIReasoningReport(
            focusQuestion: "How should this course be structured?",
            assumptions: ["Structure improves outcomes."],
            reasoningSteps: [
                AIReasoningStep(
                    id: UUID(),
                    title: "Reasoning",
                    analysis: "Built module structure.",
                    evidence: ["OpenAlex API"]
                )
            ],
            conclusion: "Three-stage progression.",
            confidenceScore: 0.83
        ),
        researchTrace: AIResearchTrace(
            engineName: "WCS Engine",
            retrievalMode: "Hybrid",
            generatedQueries: ["ai operator curriculum"],
            evidenceCards: [
                AIEvidenceCard(
                    id: UUID(),
                    title: "Sample Source",
                    source: "OpenAlex",
                    snippet: "Evidence",
                    relevanceScore: 0.8,
                    freshnessScore: 0.8
                )
            ],
            qualityGate: AIQualityGate(
                passed: true,
                threshold: 0.7,
                score: 0.81,
                rationale: "Good evidence quality."
            ),
            citationMap: [
                AICitationMapping(
                    id: UUID(),
                    claim: "Course should have progressive modules.",
                    sourceTitle: "Sample Source",
                    sourceSystem: "OpenAlex"
                )
            ]
        ),
        cohortSelection: AICohortSelection(
            cohortType: .weeklyCohort,
            recommendedSize: 30,
            rationale: "Balanced facilitation and peer learning."
        ),
        reportFindings: findings
    )
}
