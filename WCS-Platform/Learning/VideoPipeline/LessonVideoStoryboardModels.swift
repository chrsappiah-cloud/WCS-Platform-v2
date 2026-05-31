//
//  LessonVideoStoryboardModels.swift
//  WCS-Platform
//
//  Mootion-style lesson video: narrative → storyboard → short scenes → narration → compose → review.
//  The app sends a structured storyboard to the BFF; clip generation stays behind a **provider adapter**
//  (OpenAI Videos / Sora today — note vendor deprecation — Luma, LTX, self-hosted, etc.).
//

import Foundation

// MARK: - Pipeline lifecycle (orchestration)

/// Stages the backend orchestrator implements; mirrors a controllable studio, not one monolithic model call.
enum LessonVideoPipelineStage: String, Codable, Sendable, CaseIterable {
    /// Lesson text, objectives, glossary, assessment hooks.
    case ingest
    /// LLM / parser → scenes with duration, shot intent, narration, on-screen copy.
    case plan
    /// Per-scene media jobs (short clips, image-guided frames, retrievals).
    case generate
    /// TTS + caption timing per scene.
    case narrate
    /// Timeline: transitions, lower-thirds, module markers, export MP4/HLS.
    case compose
    /// Teacher approve / per-scene rerender / final publish.
    case review
}

/// How the client asks the BFF to behave for this request.
enum LessonVideoClientPipelineMode: String, Codable, Sendable {
    /// Single `textToVideoPrompt` → one asset (legacy Edge function contract).
    case legacySingleClip = "legacy_single_clip"
    /// Scene list + optional master prompt; BFF should render clips and compose (or queue jobs).
    case sceneOrchestrationV1 = "scene_orchestration_v1"
}

/// Async clip / module render tracking (BFF ↔ worker); client may poll or subscribe later.
enum LessonVideoRenderJobStatus: String, Codable, Sendable {
    case queued
    case planning
    case planned
    case awaitingReview = "awaiting_review"
    case approvedForRender = "approved_for_render"
    case rendering
    case partialRenderComplete = "partial_render_complete"
    case readyForComposition = "ready_for_composition"
    case composing
    case qaReview = "qa_review"
    case inProgress = "in_progress"
    case completed
    case failed

    static func normalized(from raw: String) -> LessonVideoRenderJobStatus? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch t {
        case "queued": return .queued
        case "planning": return .planning
        case "planned": return .planned
        case "awaiting_review", "awaitingreview": return .awaitingReview
        case "approved_for_render", "approvedforrender": return .approvedForRender
        case "rendering": return .rendering
        case "partial_render_complete", "partialrendercomplete": return .partialRenderComplete
        case "ready_for_composition", "readyforcomposition": return .readyForComposition
        case "composing": return .composing
        case "qa_review", "qareview": return .qaReview
        case "in_progress", "inprogress", "running": return .inProgress
        case "completed", "complete", "succeeded": return .completed
        case "failed", "error": return .failed
        default: return nil
        }
    }

    var displayLabel: String {
        switch self {
        case .queued: return "Queued"
        case .planning: return "Planning"
        case .planned: return "Planned"
        case .awaitingReview: return "Awaiting review"
        case .approvedForRender: return "Approved for render"
        case .rendering: return "Rendering"
        case .partialRenderComplete: return "Partial render complete"
        case .readyForComposition: return "Ready for composition"
        case .composing: return "Composing"
        case .qaReview: return "QA review"
        case .inProgress: return "In progress"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}

// MARK: - Chapter 9–aligned structured plans (content / motion / conditioning)

/// Camera motion hint (MoCoGAN-style motion latent at app level).
enum CameraMotion: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case staticShot = "static"
    case slowZoomIn = "slow_zoom_in"
    case slowZoomOut = "slow_zoom_out"
    case panLeft = "pan_left"
    case panRight = "pan_right"
    case dollyIn = "dolly_in"
    case dollyOut = "dolly_out"

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .staticShot: return "Static"
        case .slowZoomIn: return "Slow zoom in"
        case .slowZoomOut: return "Slow zoom out"
        case .panLeft: return "Pan left"
        case .panRight: return "Pan right"
        case .dollyIn: return "Dolly in"
        case .dollyOut: return "Dolly out"
        }
    }

    static func inferred(fromShotType shotType: String?) -> CameraMotion {
        switch shotType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "demo", "close_up", "closeup":
            return .dollyIn
        case "recap", "outro":
            return .slowZoomOut
        case "pan", "wide_pan":
            return .panRight
        case "wide_explainer", "educational_explain", "explain":
            return .slowZoomIn
        default:
            return .staticShot
        }
    }
}

struct ScenePathPoint: Codable, Hashable, Sendable {
    var x: Double
    var y: Double
}

/// How the scene moves (motion latent).
struct MotionPlan: Codable, Hashable, Sendable {
    var type: CameraMotion
    /// Normalized intensity 0…1 (feeds image-sequence motion multiplier).
    var speed: Double
    var pathControlPoints: [ScenePathPoint]?

    static let `default` = MotionPlan(type: .slowZoomIn, speed: 0.5, pathControlPoints: nil)
}

/// What appears in the scene (content latent).
struct ContentPlan: Codable, Hashable, Sendable {
    var entities: [String]
    var actions: [String]
    var environment: String

    static func inferred(
        narration: String,
        visualPrompt: String,
        onScreenText: String?
    ) -> ContentPlan {
        let narrationTrimmed = narration.trimmingCharacters(in: .whitespacesAndNewlines)
        let headline = onScreenText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let entities: [String] = {
            if !headline.isEmpty { return [headline] }
            let firstSentence = narrationTrimmed.split(separator: ".").first.map(String.init) ?? narrationTrimmed
            let trimmed = firstSentence.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? [] : [String(trimmed.prefix(120))]
        }()
        return ContentPlan(
            entities: entities,
            actions: [],
            environment: String(visualPrompt.trimmingCharacters(in: .whitespacesAndNewlines).prefix(280))
        )
    }
}

/// Diffusion-style conditioning bundle (Ch. 6): text, references, style, motion.
struct SceneConditioning: Codable, Hashable, Sendable {
    var textPrompt: String
    var negativePrompt: String?
    var referenceImageURL: String?
    var referenceVideoURL: String?
    var cameraMotion: CameraMotion
    var stylePreset: String
}

/// Backend model family (VideoCrafter-style diffusion vs MAGVIT-style transformer).
enum VideoBackendModel: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case videoDiffusion = "video_diffusion"
    case videoTransformer = "video_transformer"
    case imageSequence = "image_sequence"

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .videoDiffusion: return "Diffusion video"
        case .videoTransformer: return "Transformer video"
        case .imageSequence: return "Image sequence (on-device)"
        }
    }
}

struct PostProcessingOptions: Codable, Hashable, Sendable {
    var targetFPS: Int?
    var enableFrameInterpolation: Bool
    var enableUpscaling: Bool

    static let `default` = PostProcessingOptions(
        targetFPS: nil,
        enableFrameInterpolation: false,
        enableUpscaling: false
    )
}

// MARK: - Storyboard schema

/// One scene in a lesson storyboard (typically 5–20s of generated or retrieved video before composition).
struct LessonVideoScenePlan: Codable, Hashable, Sendable {
    var sceneId: String
    var learningObjective: String?
    var narrationText: String
    var visualPrompt: String
    var shotType: String?
    var durationSeconds: Int?
    var onScreenText: String?
    var referenceImageURL: String?
    var needsDiagram: Bool?
    var assessmentCheckpoint: String?
    /// Structured conditioning for remote diffusion / transformer backends.
    var conditioning: SceneConditioning?
    /// MoCoGAN-style motion plan.
    var motion: MotionPlan?
    /// MoCoGAN-style content plan.
    var content: ContentPlan?
    /// Preferred generative backend for this scene.
    var backendModel: VideoBackendModel?
    /// Optional frame interpolation / upscale hints after generation.
    var postProcessing: PostProcessingOptions?
}

/// Full storyboard for one lesson clip or module video (client-generated draft for BFF refinement).
struct LessonVideoStoryboard: Codable, Hashable, Sendable {
    var storyboardId: String
    var pipelineVersion: String
    var moduleId: String?
    var moduleTitle: String?
    var lessonId: String
    var lessonTitle: String?
    var scenes: [LessonVideoScenePlan]
    /// Optional aggregate prompt; BFF may ignore when per-scene `visualPrompt` is present.
    var masterVisualPrompt: String?
}
