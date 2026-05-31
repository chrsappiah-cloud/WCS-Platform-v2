//
//  InstructionalLessonVideoPipeline.swift
//  WCS-Platform
//
//  Converts lesson text (notes/script) into instructional MP4 output using:
//  Supabase + OpenAI Sora (primary) → Apple Foundation Models / Image Playground → AVFoundation fallback.
//

import Foundation

struct InstructionalVideoRenderResult: Sendable {
    let storyboard: LessonVideoStoryboard
    let planSource: String
    let clipURL: URL
    let composedURL: URL?
    let renderSource: String
    let lessonScriptExcerpt: String
}

enum InstructionalLessonVideoError: LocalizedError {
    case emptyLessonScript
    case noScenesPlanned
    case renderFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyLessonScript:
            return "Lesson text is empty. Add instructional notes before generating video."
        case .noScenesPlanned:
            return "Storyboard planning produced no scenes."
        case .renderFailed(let detail):
            return "Instructional video render failed: \(detail)"
        }
    }
}

struct InstructionalLessonVideoPipeline {
    private let hybrid = HybridLessonVideoOrchestrator()
    private let imageSequenceRenderer = AVFoundationImageSequenceRenderer()
    private let lessonComposer = AVFoundationLessonComposer()

    /// Plan → render → compose from lesson text for instructional playback.
    func renderInstructionalLessonVideo(
        draft: AdminCourseDraft,
        module: AdminModuleDraft,
        lesson: AdminLessonDraft,
        settings: ImageSequenceRenderSettings = .default
    ) async throws -> InstructionalVideoRenderResult {
        var script = LessonManualVideoBackup.stripMachineLines(from: lesson.notes)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if script.isEmpty {
            script = """
            \(lesson.title). Module: \(module.title). Course: \(draft.title).
            Learning outcomes: \(draft.outcomes.joined(separator: "; ")).
            Explain core concepts with clear examples suitable for \(draft.targetAudience).
            """
        }
        guard !script.isEmpty else {
            throw InstructionalLessonVideoError.emptyLessonScript
        }

        let planRequest = LessonVideoPlanRequest(
            lessonId: lesson.id.uuidString,
            moduleId: module.id.uuidString,
            moduleTitle: module.title,
            lessonTitle: lesson.title,
            sourceScript: script,
            learningObjectives: draft.outcomes,
            glossary: [],
            assessmentPrompts: [lesson.title],
            targetAgeBand: draft.level,
            styleProfileId: nil,
            referenceAssetIds: []
        )

        let planned = try await hybrid.planStoryboard(planRequest)
        var storyboard = planned.storyboard
        storyboard.ensureStructuredPlansForAllScenes(stylePreset: draft.level)
        guard var scene = storyboard.scenes.first else {
            throw InstructionalLessonVideoError.noScenesPlanned
        }
        scene.ensureStructuredPlans(stylePreset: draft.level)

        let (clipURL, renderSource) = try await renderWithFallbackChain(
            draft: draft,
            module: module,
            lesson: lesson,
            storyboard: storyboard,
            scene: scene,
            settings: settings
        )

        var composedURL: URL?
        if storyboard.scenes.count > 1,
           LessonVideoGenerationSettings.generationApproach == .onDeviceExperimental {
            composedURL = try? await hybrid.renderOnDeviceLesson(storyboard: storyboard, settings: settings)
        } else {
            composedURL = try? await lessonComposer.composeLesson(clips: [clipURL])
        }

        return InstructionalVideoRenderResult(
            storyboard: storyboard,
            planSource: planned.source,
            clipURL: clipURL,
            composedURL: composedURL,
            renderSource: renderSource,
            lessonScriptExcerpt: String(script.prefix(240))
        )
    }

    private func renderWithFallbackChain(
        draft: AdminCourseDraft,
        module: AdminModuleDraft,
        lesson: AdminLessonDraft,
        storyboard: LessonVideoStoryboard,
        scene: LessonVideoScenePlan,
        settings: ImageSequenceRenderSettings
    ) async throws -> (URL, String) {
        if WCSBackendStackSettings.shouldActivateLiveBackendStack,
           LessonVideoGenerationSettings.isRemoteTextToVideoEnabled,
           LessonVideoGenerationSettings.generationApproach != .onDeviceExperimental,
           ProcessInfo.processInfo.environment["WCS_UI_TEST_LOCAL_VIDEO_ONLY"] != "1" {
            if let remote = await RemoteLessonVideoClient.requestPlaybackURL(
                draft: draft,
                module: module,
                lesson: lesson,
                storyboard: storyboard
            ), remote.isFileURL || remote.scheme?.lowercased() == "https" {
                return (remote, "OpenAI via Supabase Edge (instructional text → video)")
            }
        }

        if LessonVideoGenerationSettings.generationApproach == .onDeviceExperimental
            || AppleFoundationLessonVideoService.availabilitySnapshot().isReferenceImageGenerationAvailable {
            do {
                let rendered = try await hybrid.renderFirstScene(
                    draft: draft,
                    module: module,
                    lesson: lesson,
                    storyboard: storyboard,
                    scene: scene,
                    settings: settings
                )
                return (rendered.clipURL, rendered.source)
            } catch {
                // Fall through to deterministic AVFoundation path.
            }
        }

        var localScene = scene
        localScene.backendModel = .imageSequence
        do {
            let clip = try await imageSequenceRenderer.renderSceneClip(scene: localScene, settings: settings)
            return (clip, "AVFoundation image-sequence (instructional text → MP4 fallback)")
        } catch let err {
            throw InstructionalLessonVideoError.renderFailed(err.localizedDescription)
        }
    }
}
