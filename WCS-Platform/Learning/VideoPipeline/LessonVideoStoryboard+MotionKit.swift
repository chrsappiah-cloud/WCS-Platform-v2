//
//  LessonVideoStoryboard+MotionKit.swift
//  WCS-Platform
//
//  Bridges the admin “Motion kit” heuristics into a Mootion-style scene list for the BFF.
//

import Foundation

extension LessonVideoStoryboard {
    /// Builds a v1 storyboard from the existing `MotionTextToVideoKit` (scene beats + master prompt).
    static func sceneOrchestrationV1(
        storyboardId: String = UUID().uuidString,
        moduleId: UUID,
        moduleTitle: String,
        lessonId: UUID,
        lessonTitle: String,
        motionKit: MotionTextToVideoKit
    ) -> LessonVideoStoryboard {
        let beats = motionKit.sceneBeats
        let sceneCount = max(beats.count, 1)
        let rawPerScene = motionKit.targetDurationSeconds / sceneCount
        let perScene = min(20, max(5, rawPerScene))

        let scenes: [LessonVideoScenePlan] = beats.enumerated().map { index, beat in
            let beatTrimmed = beat.trimmingCharacters(in: .whitespacesAndNewlines)
            let onScreen = String(beatTrimmed.prefix(120))
            let visual = """
                \(motionKit.visualStyle) \(motionKit.shotPrompt)
                Scene \(index + 1) focus: \(beatTrimmed)
                """
            var scene = LessonVideoScenePlan(
                sceneId: "scene-\(index + 1)",
                learningObjective: nil,
                narrationText: beatTrimmed,
                visualPrompt: visual,
                shotType: "educational_explain",
                durationSeconds: perScene,
                onScreenText: onScreen.isEmpty ? nil : onScreen,
                referenceImageURL: nil,
                needsDiagram: beatTrimmed.localizedCaseInsensitiveContains("diagram")
                    || beatTrimmed.localizedCaseInsensitiveContains("chart"),
                assessmentCheckpoint: index == beats.count - 1
                    ? "Learner recalls one takeaway from \(lessonTitle)."
                    : nil,
                conditioning: SceneConditioning(
                    textPrompt: visual,
                    negativePrompt: nil,
                    referenceImageURL: nil,
                    referenceVideoURL: nil,
                    cameraMotion: .slowZoomIn,
                    stylePreset: motionKit.visualStyle
                ),
                motion: MotionPlan(type: .slowZoomIn, speed: 0.55, pathControlPoints: nil),
                content: ContentPlan.inferred(
                    narration: beatTrimmed,
                    visualPrompt: visual,
                    onScreenText: onScreen.isEmpty ? nil : onScreen
                ),
                backendModel: .videoDiffusion,
                postProcessing: nil
            )
            scene.syncLegacyFieldsFromStructuredPlans()
            return scene
        }

        return LessonVideoStoryboard(
            storyboardId: storyboardId,
            pipelineVersion: "scene_orchestration_v1",
            moduleId: moduleId.uuidString,
            moduleTitle: moduleTitle,
            lessonId: lessonId.uuidString,
            lessonTitle: lessonTitle,
            scenes: scenes,
            masterVisualPrompt: motionKit.shotPrompt
        )
    }
}
