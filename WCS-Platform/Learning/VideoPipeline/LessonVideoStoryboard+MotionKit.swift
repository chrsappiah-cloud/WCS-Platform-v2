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
            return LessonVideoScenePlan(
                sceneId: "scene-\(index + 1)",
                learningObjective: nil,
                narrationText: beatTrimmed,
                visualPrompt: """
                \(motionKit.visualStyle) \(motionKit.shotPrompt)
                Scene \(index + 1) focus: \(beatTrimmed)
                """,
                shotType: "educational_explain",
                durationSeconds: perScene,
                onScreenText: onScreen.isEmpty ? nil : onScreen,
                referenceImageURL: nil,
                needsDiagram: beatTrimmed.localizedCaseInsensitiveContains("diagram")
                    || beatTrimmed.localizedCaseInsensitiveContains("chart"),
                assessmentCheckpoint: index == beats.count - 1
                    ? "Learner recalls one takeaway from \(lessonTitle)."
                    : nil
            )
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
