//
//  AppleFoundationLessonVideoService.swift
//  WCS-Platform
//
//  On-device lesson video pipeline using Apple's Foundation Models (storyboard planning)
//  and Image Playground (scene reference frames) composed with AVFoundation.
//

import Foundation
import FoundationModels
import ImagePlayground
import UIKit

enum AppleFoundationVideoError: LocalizedError {
    case foundationModelUnavailable(String)
    case imagePlaygroundUnavailable
    case storyboardPlanningFailed(String)
    case referenceImageGenerationFailed(String)
    case noScenesToRender

    var errorDescription: String? {
        switch self {
        case .foundationModelUnavailable(let reason):
            return "Apple Foundation Model unavailable: \(reason)"
        case .imagePlaygroundUnavailable:
            return "Image Playground is unavailable on this device."
        case .storyboardPlanningFailed(let detail):
            return "Storyboard planning failed: \(detail)"
        case .referenceImageGenerationFailed(let detail):
            return "Reference image generation failed: \(detail)"
        case .noScenesToRender:
            return "Storyboard has no scenes to render."
        }
    }
}

struct AppleFoundationVideoAvailability: Sendable {
    let foundationModelState: GenerationCapabilityCheck.State
    let foundationModelDetail: String
    let imagePlaygroundState: GenerationCapabilityCheck.State
    let imagePlaygroundDetail: String

    var isStoryboardPlanningAvailable: Bool {
        foundationModelState == .online || foundationModelState == .configured
    }

    var isReferenceImageGenerationAvailable: Bool {
        imagePlaygroundState == .online || imagePlaygroundState == .configured
    }
}

@Generable(description: "A single educational lesson video scene")
private struct FMGeneratedScenePlan {
    @Guide(description: "Scene identifier such as scene-1")
    var sceneId: String
    @Guide(description: "One sentence learning objective")
    var learningObjective: String
    @Guide(description: "Narration script for the scene")
    var narrationText: String
    @Guide(description: "Visual prompt for image or video generation")
    var visualPrompt: String
    @Guide(description: "Duration in seconds between 5 and 20")
    var durationSeconds: Int
    @Guide(description: "Short on-screen caption")
    var onScreenText: String
}

@Generable(description: "Educational lesson video storyboard")
private struct FMGeneratedStoryboard {
    @Guide(description: "Three to five scenes for the lesson")
    var scenes: [FMGeneratedScenePlan]
    @Guide(description: "Master visual style prompt for the lesson")
    var masterVisualPrompt: String
}

struct AppleFoundationLessonVideoService {
    private let imageSequenceRenderer = AVFoundationImageSequenceRenderer()
    private let lessonComposer = AVFoundationLessonComposer()

    static func availabilitySnapshot() -> AppleFoundationVideoAvailability {
        let model = SystemLanguageModel.default
        let fmState: GenerationCapabilityCheck.State
        let fmDetail: String
        switch model.availability {
        case .available:
            fmState = .online
            fmDetail = "On-device Foundation Model ready for storyboard planning."
        case .unavailable(let reason):
            fmState = .offline
            fmDetail = foundationModelUnavailableReason(reason)
        }

        let imageAvailable = ImagePlaygroundViewController.isAvailable
        let imageState: GenerationCapabilityCheck.State = imageAvailable ? .online : .offline
        let imageDetail = imageAvailable
            ? "Image Playground ready for scene reference frames."
            : "Image Playground unavailable (Apple Intelligence may be disabled)."

        return AppleFoundationVideoAvailability(
            foundationModelState: fmState,
            foundationModelDetail: fmDetail,
            imagePlaygroundState: imageState,
            imagePlaygroundDetail: imageDetail
        )
    }

    func planStoryboard(request: LessonVideoPlanRequest) async throws -> LessonVideoStoryboard {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw AppleFoundationVideoError.foundationModelUnavailable(
                Self.foundationModelUnavailableReason(extractUnavailableReason(from: model.availability))
            )
        }

        let objectives = request.learningObjectives.joined(separator: "; ")
        let prompt = """
        Plan a concise educational lesson video storyboard.
        Module: \(request.moduleTitle)
        Lesson: \(request.lessonTitle)
        Audience level: \(request.targetAgeBand)
        Learning objectives: \(objectives.isEmpty ? "Practical mastery" : objectives)
        Source script:
        \(request.sourceScript.prefix(4000))

        Return 3 to 5 scenes. Each scene should be 5–20 seconds with clear narration and a visual prompt suitable for educational motion graphics.
        """

        do {
            let session = LanguageModelSession(
                model: model,
                instructions: """
                You are an expert instructional designer for World Class Scholars.
                Produce structured lesson video scenes with practical, age-appropriate language.
                """
            )
            let response = try await session.respond(to: prompt, generating: FMGeneratedStoryboard.self)
            return mapGeneratedStoryboard(response.content, request: request)
        } catch {
            throw AppleFoundationVideoError.storyboardPlanningFailed(error.localizedDescription)
        }
    }

    func enrichStoryboardWithReferenceImages(_ storyboard: LessonVideoStoryboard) async throws -> LessonVideoStoryboard {
        guard ImagePlaygroundViewController.isAvailable else {
            return storyboard
        }

        let creator = try await ImageCreator()
        guard !creator.availableStyles.isEmpty else {
            throw AppleFoundationVideoError.imagePlaygroundUnavailable
        }

        let style = creator.availableStyles.contains(.illustration)
            ? ImagePlaygroundStyle.illustration
            : creator.availableStyles[0]

        var enrichedScenes: [LessonVideoScenePlan] = []
        for scene in storyboard.scenes {
            var updated = scene
            if scene.referenceImageURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                let conceptText = """
                Educational illustration for "\(storyboard.lessonTitle ?? "lesson")".
                \(scene.generationVisualPrompt())
                Clean labels, high contrast, no text clutter.
                """
                do {
                    let fileURL = try await generateReferenceImageFile(
                        creator: creator,
                        concepts: [.text(conceptText)],
                        style: style,
                        sceneId: scene.sceneId
                    )
                    updated.referenceImageURL = fileURL.absoluteString
                } catch {
                    // Keep scene without reference image; renderer still draws text overlays.
                    continue
                }
            }
            enrichedScenes.append(updated)
        }

        var enriched = storyboard
        enriched.scenes = enrichedScenes.isEmpty ? storyboard.scenes : enrichedScenes
        return enriched
    }

    func renderOnDeviceLesson(
        storyboard: LessonVideoStoryboard,
        settings: ImageSequenceRenderSettings = .default
    ) async throws -> URL {
        guard !storyboard.scenes.isEmpty else {
            throw AppleFoundationVideoError.noScenesToRender
        }

        var clipURLs: [URL] = []
        for scene in storyboard.scenes {
            let clip = try await imageSequenceRenderer.renderSceneClip(scene: scene, settings: settings)
            clipURLs.append(clip)
        }
        return try await lessonComposer.composeLesson(clips: clipURLs)
    }

    // MARK: - Private

    private func mapGeneratedStoryboard(
        _ generated: FMGeneratedStoryboard,
        request: LessonVideoPlanRequest
    ) -> LessonVideoStoryboard {
        var storyboard = LessonVideoStoryboard(
            storyboardId: "apple-fm-\(request.lessonId)",
            pipelineVersion: LessonVideoClientPipelineMode.sceneOrchestrationV1.rawValue,
            moduleId: request.moduleId,
            moduleTitle: request.moduleTitle,
            lessonId: request.lessonId,
            lessonTitle: request.lessonTitle,
            scenes: generated.scenes.enumerated().map { index, scene in
                var plan = LessonVideoScenePlan(
                    sceneId: scene.sceneId.isEmpty ? "scene-\(index + 1)" : scene.sceneId,
                    learningObjective: scene.learningObjective,
                    narrationText: scene.narrationText,
                    visualPrompt: scene.visualPrompt,
                    shotType: "educational_explain",
                    durationSeconds: min(20, max(5, scene.durationSeconds)),
                    onScreenText: scene.onScreenText,
                    referenceImageURL: nil,
                    needsDiagram: scene.visualPrompt.localizedCaseInsensitiveContains("diagram")
                        || scene.visualPrompt.localizedCaseInsensitiveContains("chart"),
                    assessmentCheckpoint: index == generated.scenes.count - 1
                        ? "Learner recalls one takeaway from \(request.lessonTitle)."
                        : nil,
                    conditioning: nil,
                    motion: nil,
                    content: nil,
                    backendModel: .videoDiffusion,
                    postProcessing: nil
                )
                plan.ensureStructuredPlans(stylePreset: request.targetAgeBand ?? "educational")
                return plan
            },
            masterVisualPrompt: generated.masterVisualPrompt
        )
        storyboard.ensureStructuredPlansForAllScenes(stylePreset: request.targetAgeBand ?? "educational")
        return storyboard
    }

    private func generateReferenceImageFile(
        creator: ImageCreator,
        concepts: [ImagePlaygroundConcept],
        style: ImagePlaygroundStyle,
        sceneId: String
    ) async throws -> URL {
        var generatedImage: CGImage?
        for try await created in creator.images(for: concepts, style: style, limit: 1) {
            generatedImage = created.cgImage
            break
        }
        guard let cgImage = generatedImage else {
            throw AppleFoundationVideoError.referenceImageGenerationFailed("No image returned.")
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wcs-apple-fm-ref-\(sceneId)-\(UUID().uuidString)")
            .appendingPathExtension("jpg")
        let uiImage = UIImage(cgImage: cgImage)
        guard let data = uiImage.jpegData(compressionQuality: 0.92) else {
            throw AppleFoundationVideoError.referenceImageGenerationFailed("Could not encode JPEG.")
        }
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func foundationModelUnavailableReason(
        _ reason: SystemLanguageModel.Availability.UnavailableReason
    ) -> String {
        switch reason {
        case .deviceNotEligible:
            return "Device not eligible for Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Enable Apple Intelligence in Settings."
        case .modelNotReady:
            return "Foundation Model is not ready yet."
        @unknown default:
            return "Foundation Model unavailable."
        }
    }

    private func extractUnavailableReason(
        from availability: SystemLanguageModel.Availability
    ) -> SystemLanguageModel.Availability.UnavailableReason {
        if case .unavailable(let reason) = availability {
            return reason
        }
        return .modelNotReady
    }
}
