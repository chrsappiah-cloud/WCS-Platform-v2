//
//  WCSLessonVideoPipelinePayloads.swift
//  WCS-Platform
//
//  Typed request/response contracts for storyboard-first lesson video pipeline endpoints.
//

import Foundation

struct LessonVideoPlanRequest: Codable, Sendable {
    let lessonId: String
    let moduleId: String?
    let moduleTitle: String?
    let lessonTitle: String?
    let sourceScript: String
    let learningObjectives: [String]
    let glossary: [String]
    let assessmentPrompts: [String]
    let targetAgeBand: String?
    let styleProfileId: String?
    let referenceAssetIds: [String]
}

struct LessonVideoPlanResponse: Codable, Sendable {
    let lessonId: String
    let storyboard: LessonVideoStoryboard
    let plannerVersion: String?
    let status: String
}

struct LessonVideoSceneRenderRequest: Codable, Sendable {
    let lessonId: String
    let moduleId: String?
    let moduleTitle: String?
    let scene: LessonVideoScenePlan
    let providerBackendHint: String?
}

struct LessonVideoRenderJobResponse: Codable, Sendable {
    let renderJobId: String
    let sceneId: String?
    let lessonId: String?
    let status: String
    let provider: String?
    let playbackURL: String?
    let errorMessage: String?

    var normalizedStatus: LessonVideoRenderJobStatus? {
        LessonVideoRenderJobStatus.normalized(from: status)
    }

    enum CodingKeys: String, CodingKey {
        case renderJobId = "render_job_id"
        case sceneId = "scene_id"
        case lessonId = "lesson_id"
        case status
        case provider
        case playbackURL = "playback_url"
        case errorMessage = "error_message"
    }
}

struct LessonVideoComposeRequest: Codable, Sendable {
    let lessonId: String
    let moduleId: String?
    let includeCaptions: Bool
    let includeChapterMarkers: Bool
}

struct LessonVideoComposeResponse: Codable, Sendable {
    let lessonId: String
    let status: String
    let outputURL: String?

    enum CodingKeys: String, CodingKey {
        case lessonId = "lesson_id"
        case status
        case outputURL = "output_url"
    }
}

struct LessonVideoOutputResponse: Codable, Sendable {
    let lessonId: String
    let playbackURL: String?
    let thumbnailURL: String?
    let chapters: [String]
    let subtitleURL: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case lessonId = "lesson_id"
        case playbackURL = "playback_url"
        case thumbnailURL = "thumbnail_url"
        case chapters
        case subtitleURL = "subtitle_url"
        case status
    }
}
