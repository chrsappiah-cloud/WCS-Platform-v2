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
    case inProgress = "in_progress"
    case completed
    case failed
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
