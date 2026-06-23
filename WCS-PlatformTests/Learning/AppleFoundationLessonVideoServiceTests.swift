import Foundation
import AVFoundation
import Testing
@testable import WCS_Platform

struct AppleFoundationLessonVideoServiceTests {
    @Test
    func availabilitySnapshot_reportsAppleStack() {
        let snapshot = AppleFoundationLessonVideoService.availabilitySnapshot()
        #expect(!snapshot.foundationModelDetail.isEmpty)
        #expect(!snapshot.imagePlaygroundDetail.isEmpty)
    }

    @Test
    func effectiveProviderBackendHint_defaultsToSoraWhenRemoteEnabled() {
        if LessonVideoGenerationSettings.isRemoteTextToVideoEnabled {
            #expect(LessonVideoGenerationSettings.effectiveProviderBackendHint == "sora"
                || LessonVideoGenerationSettings.providerBackendHint != nil)
        }
    }

    @Test
    func hybridOrchestrator_planStoryboard_returnsScenes() async throws {
        let request = LessonVideoPlanRequest(
            lessonId: UUID().uuidString,
            moduleId: UUID().uuidString,
            moduleTitle: "Test Module",
            lessonTitle: "Intro Lesson",
            sourceScript: "Explain core concepts with examples.",
            learningObjectives: ["Understand basics"],
            glossary: [],
            assessmentPrompts: ["Quiz"],
            targetAgeBand: "Adult",
            styleProfileId: nil,
            referenceAssetIds: []
        )

        let orchestrator = HybridLessonVideoOrchestrator()
        let planned = try await orchestrator.planStoryboard(request)
        #expect(!planned.storyboard.scenes.isEmpty)
        #expect(!planned.source.isEmpty)
    }

    @Test
    func textLessonScript_rendersPlayableMp4Clip() async throws {
        let request = LessonVideoPlanRequest(
            lessonId: UUID().uuidString,
            moduleId: UUID().uuidString,
            moduleTitle: "Photosynthesis Module",
            lessonTitle: "How Plants Make Energy",
            sourceScript: """
            Plants convert sunlight into chemical energy through photosynthesis.
            Chlorophyll absorbs light. Carbon dioxide and water produce glucose and oxygen.
            """,
            learningObjectives: ["Explain photosynthesis steps"],
            glossary: ["chlorophyll", "glucose"],
            assessmentPrompts: ["Name the inputs and outputs of photosynthesis."],
            targetAgeBand: "High school",
            styleProfileId: nil,
            referenceAssetIds: []
        )

        let orchestrator = HybridLessonVideoOrchestrator()
        let planned = try await orchestrator.planStoryboard(request)
        guard let scene = planned.storyboard.scenes.first else {
            Issue.record("Expected at least one scene from text lesson script.")
            return
        }

        let renderer = AVFoundationImageSequenceRenderer()
        let clipURL = try await renderer.renderSceneClip(
            scene: scene,
            settings: ImageSequenceRenderSettings(
                fps: 24,
                resolution: .p720,
                animationIntensity: 1.0,
                diagramStyle: .flow
            )
        )

        #expect(clipURL.pathExtension.lowercased() == "mp4")
        let attrs = try FileManager.default.attributesOfItem(atPath: clipURL.path)
        let bytes = (attrs[.size] as? NSNumber)?.intValue ?? 0
        #expect(bytes > 10_000, "Rendered clip should be a non-trivial MP4 file.")

        let asset = AVURLAsset(url: clipURL)
        let duration = try await asset.load(.duration)
        #expect(duration.seconds > 1.0)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        #expect(!tracks.isEmpty)
    }
}
