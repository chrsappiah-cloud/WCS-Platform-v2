//
//  AppleFoundationLessonVideoService+OnDevice.swift
//  WCS-Platform
//
//  iOS 26+ Apple Intelligence integrations (Foundation Models, Image Playground).
//

#if canImport(FoundationModels)
import Foundation
import FoundationModels
import ImagePlayground
import UIKit

@available(iOS 26, *)
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

@available(iOS 26, *)
@Generable(description: "Educational lesson video storyboard")
private struct FMGeneratedStoryboard {
    @Guide(description: "Three to five scenes for the lesson")
    var scenes: [FMGeneratedScenePlan]
    @Guide(description: "Master visual style prompt for the lesson")
    var masterVisualPrompt: String
}

@available(iOS 26, *)
extension AppleFoundationLessonVideoService {
    static func availabilitySnapshotOnDevice() -> AppleFoundationVideoAvailability {
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

    func planStoryboardOnDevice(request: LessonVideoPlanRequest) async throws -> LessonVideoStoryboard {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw AppleFoundationVideoError.foundationModelUnavailable(
                Self.foundationModelUnavailableReason(extractUnavailableReason(from: model.availability))
            )
        }

        let objectives = request.learningObjectives.joined(separator: "; ")
        let moduleTitle = request.moduleTitle ?? "Untitled module"
        let lessonTitle = request.lessonTitle ?? "Untitled lesson"
        let targetAgeBand = request.targetAgeBand ?? "General learners"
        let prompt = """
        Plan a concise educational lesson video storyboard.
        Module: \(moduleTitle)
        Lesson: \(lessonTitle)
        Audience level: \(targetAgeBand)
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

    func enrichStoryboardWithReferenceImagesOnDevice(_ storyboard: LessonVideoStoryboard) async throws -> LessonVideoStoryboard {
        let imagePlaygroundAvailable = await MainActor.run {
            ImagePlaygroundViewController.isAvailable
        }
        guard imagePlaygroundAvailable else {
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
                    continue
                }
            }
            enrichedScenes.append(updated)
        }

        var enriched = storyboard
        enriched.scenes = enrichedScenes.isEmpty ? storyboard.scenes : enrichedScenes
        return enriched
    }

    private func mapGeneratedStoryboard(
        _ generated: FMGeneratedStoryboard,
        request: LessonVideoPlanRequest
    ) -> LessonVideoStoryboard {
        let lessonTitle = request.lessonTitle ?? "this lesson"
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
                        ? "Learner recalls one takeaway from \(lessonTitle)."
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
#endif
