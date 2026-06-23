//
//  AppleFoundationLessonVideoService.swift
//  WCS-Platform
//
//  On-device lesson video pipeline using Apple's Foundation Models (storyboard planning)
//  and Image Playground (scene reference frames) composed with AVFoundation.
//

import Foundation
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

struct AppleFoundationLessonVideoService {
    private let imageSequenceRenderer = AVFoundationImageSequenceRenderer()
    private let lessonComposer = AVFoundationLessonComposer()

    static func availabilitySnapshot() -> AppleFoundationVideoAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            return availabilitySnapshotOnDevice()
        }
        #endif
        return AppleFoundationVideoAvailability(
            foundationModelState: .offline,
            foundationModelDetail: "Foundation Models require iOS 26 or later.",
            imagePlaygroundState: .offline,
            imagePlaygroundDetail: "Image Playground requires iOS 26 or later."
        )
    }

    func planStoryboard(request: LessonVideoPlanRequest) async throws -> LessonVideoStoryboard {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            return try await planStoryboardOnDevice(request: request)
        }
        #endif
        throw AppleFoundationVideoError.foundationModelUnavailable(
            "Foundation Models require iOS 26 or later."
        )
    }

    func enrichStoryboardWithReferenceImages(_ storyboard: LessonVideoStoryboard) async throws -> LessonVideoStoryboard {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            return try await enrichStoryboardWithReferenceImagesOnDevice(storyboard)
        }
        #endif
        return storyboard
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
}
