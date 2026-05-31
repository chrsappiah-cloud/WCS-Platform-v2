import Foundation
import Testing
@testable import WCS_Platform

struct LessonVideoScenePlanStructuredTests {
    @Test
    func ensureStructuredPlans_populatesFromLegacyFields() {
        var scene = LessonVideoScenePlan(
            sceneId: "scene-1",
            learningObjective: "Explain photosynthesis",
            narrationText: "Plants convert light into energy.",
            visualPrompt: "Sunlit leaf macro, educational diagram overlay.",
            shotType: "wide_explainer",
            durationSeconds: 10,
            onScreenText: "Photosynthesis basics",
            referenceImageURL: nil,
            needsDiagram: true,
            assessmentCheckpoint: nil
        )
        scene.ensureStructuredPlans(stylePreset: "high_school")

        #expect(scene.conditioning != nil)
        #expect(scene.motion != nil)
        #expect(scene.content != nil)
        #expect(scene.conditioning?.stylePreset == "high_school")
        #expect(scene.motion?.type == .slowZoomIn)
        #expect(scene.content?.entities.contains("Photosynthesis basics") == true)
    }

    @Test
    func generationVisualPrompt_mergesContentAndMotion() {
        var scene = LessonVideoScenePlan(
            sceneId: "scene-2",
            learningObjective: nil,
            narrationText: "Water cycles through evaporation and rain.",
            visualPrompt: "Clouds over mountains",
            shotType: "educational_explain",
            durationSeconds: 8,
            onScreenText: "The water cycle",
            referenceImageURL: nil,
            needsDiagram: false,
            assessmentCheckpoint: nil
        )
        scene.ensureStructuredPlans(stylePreset: "cinematic")
        let prompt = scene.generationVisualPrompt()
        #expect(prompt.contains("Environment:"))
        #expect(prompt.contains("Subjects:"))
        #expect(prompt.contains("Camera:"))
        #expect(prompt.contains("Style: cinematic"))
    }

    @Test
    func codable_roundTrip_preservesStructuredPlans() throws {
        var scene = LessonVideoScenePlan(
            sceneId: "scene-3",
            learningObjective: nil,
            narrationText: "Test narration",
            visualPrompt: "Test visual",
            shotType: nil,
            durationSeconds: 6,
            onScreenText: nil,
            referenceImageURL: "https://example.com/ref.jpg",
            needsDiagram: nil,
            assessmentCheckpoint: nil
        )
        scene.ensureStructuredPlans()
        scene.backendModel = .videoTransformer
        scene.postProcessing = PostProcessingOptions(targetFPS: 30, enableFrameInterpolation: true, enableUpscaling: false)

        let data = try JSONEncoder().encode(scene)
        let decoded = try JSONDecoder().decode(LessonVideoScenePlan.self, from: data)
        #expect(decoded.conditioning?.referenceImageURL == "https://example.com/ref.jpg")
        #expect(decoded.backendModel == .videoTransformer)
        #expect(decoded.postProcessing?.targetFPS == 30)
        #expect(decoded.postProcessing?.enableFrameInterpolation == true)
    }

    @Test
    func codable_decodesLegacyJSONWithoutStructuredFields() throws {
        let json = """
        {
          "sceneId": "legacy-1",
          "narrationText": "Hello",
          "visualPrompt": "Simple scene"
        }
        """
        let scene = try JSONDecoder().decode(LessonVideoScenePlan.self, from: json.data(using: .utf8)!)
        #expect(scene.sceneId == "legacy-1")
        #expect(scene.conditioning == nil)
        #expect(scene.motion == nil)
    }

    @Test
    func imageSequenceMotionMultiplier_respectsMotionSpeed() {
        var scene = LessonVideoScenePlan(
            sceneId: "scene-4",
            learningObjective: nil,
            narrationText: "n",
            visualPrompt: "v",
            shotType: "pan",
            durationSeconds: 5,
            onScreenText: nil,
            referenceImageURL: nil,
            needsDiagram: nil,
            assessmentCheckpoint: nil,
            conditioning: nil,
            motion: MotionPlan(type: .panRight, speed: 1.0, pathControlPoints: nil),
            content: nil,
            backendModel: nil,
            postProcessing: nil
        )
        let high = scene.imageSequenceMotionMultiplier(baseIntensity: 1.0)
        scene.motion = MotionPlan(type: .staticShot, speed: 0.2, pathControlPoints: nil)
        let low = scene.imageSequenceMotionMultiplier(baseIntensity: 1.0)
        #expect(high > low)
    }
}
