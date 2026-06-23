import Foundation
import AVFoundation
import Testing
@testable import WCS_Platform

struct InstructionalLessonVideoPipelineTests {
    @Test
    func backendStackSettings_defaultsToSupabaseProject() {
        #expect(WCSBackendStackSettings.supabaseProjectURL.host?.contains("supabase.co") == true)
        #expect(WCSBackendStackSettings.textToVideoEdgeURL.lastPathComponent == "wcs-lesson-text-to-video")
    }

    @Test
    func instructionalPipeline_rendersMp4FromLessonText() async throws {
        let lessonID = UUID()
        let moduleID = UUID()
        let draft = AdminCourseDraft(
            id: UUID(),
            createdAt: Date(),
            updatedAt: Date(),
            createdBy: "test",
            title: "Photosynthesis Course",
            summary: "Test",
            targetAudience: "Students",
            level: "High school",
            durationWeeks: 4,
            outcomes: ["Explain photosynthesis"],
            modules: [
                AdminModuleDraft(
                    id: moduleID,
                    title: "Energy",
                    goals: ["Understand photosynthesis"],
                    lessons: [
                        AdminLessonDraft(
                            id: lessonID,
                            title: "How plants make food",
                            kind: .video,
                            durationMinutes: 12,
                            notes: """
                            Plants convert sunlight into chemical energy.
                            Chlorophyll captures light. CO2 and water produce glucose and oxygen.
                            """
                        )
                    ]
                )
            ],
            status: .draft,
            accessTier: .freePublic,
            sourceReferences: [],
            promotionalCopy: [],
            funnelPreview: nil,
            reasoningReport: nil,
            researchTrace: nil,
            cohortSelection: AICohortSelection(cohortType: .weeklyCohort, recommendedSize: 20, rationale: "Test"),
            reportFindings: []
        )
        guard let module = draft.modules.first,
              let lesson = module.lessons.first
        else {
            Issue.record("Fixture draft missing video lesson.")
            return
        }

        let pipeline = InstructionalLessonVideoPipeline()
        let result = try await pipeline.renderInstructionalLessonVideo(
            draft: draft,
            module: module,
            lesson: lesson,
            settings: ImageSequenceRenderSettings(fps: 24, resolution: .p720, animationIntensity: 1.0, diagramStyle: .flow)
        )

        #expect(!result.storyboard.scenes.isEmpty)
        #expect(result.clipURL.pathExtension.lowercased() == "mp4")
        let asset = AVURLAsset(url: result.clipURL)
        let duration = try await asset.load(.duration)
        #expect(duration.seconds > 1.0)
        #expect(!result.lessonScriptExcerpt.isEmpty)
    }
}
