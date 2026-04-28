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
