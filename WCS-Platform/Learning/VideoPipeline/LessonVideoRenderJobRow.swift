//
//  LessonVideoRenderJobRow.swift
//  WCS-Platform
//
//  Row shape returned by Supabase Edge `wcs-lesson-video-jobs` (subset of `wcs_lesson_video_render_jobs`).
//

import Foundation

struct LessonVideoRenderJobRow: Decodable, Identifiable, Sendable {
    let id: UUID
    let courseId: String
    let moduleId: String
    let lessonId: String
    let pipelineMode: String?
    let provider: String
    let status: String
    let playbackUrl: String?
    let errorMessage: String?
    let clientAppVersion: String?
    /// ISO8601 string from Postgres (decoder-friendly across Supabase variants).
    let createdAt: String?
    let generationPromptExcerpt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case courseId = "course_id"
        case moduleId = "module_id"
        case lessonId = "lesson_id"
        case pipelineMode = "pipeline_mode"
        case provider
        case status
        case playbackUrl = "playback_url"
        case errorMessage = "error_message"
        case clientAppVersion = "client_app_version"
        case createdAt = "created_at"
        case generationPromptExcerpt = "generation_prompt_excerpt"
    }
}

struct LessonVideoRenderJobListResponse: Decodable, Sendable {
    let jobs: [LessonVideoRenderJobRow]
}

extension LessonVideoRenderJobRow {
    /// Sample rows for SwiftUI previews (no Supabase credentials).
    static var previewSamples: [LessonVideoRenderJobRow] {
        let json = #"""
        [
          {
            "id": "550e8400-e29b-41d4-a716-446655440001",
            "course_id": "course-demo",
            "module_id": "module-demo",
            "lesson_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
            "pipeline_mode": "scene_orchestration_v1",
            "provider": "ltx",
            "status": "completed",
            "playback_url": "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8",
            "error_message": null,
            "client_app_version": "1.1.0",
            "created_at": "2026-04-28T12:00:00Z",
            "generation_prompt_excerpt": "Multi-scene lesson: intro hook, concept A, worked example, recap."
          },
          {
            "id": "550e8400-e29b-41d4-a716-446655440002",
            "course_id": "course-demo",
            "module_id": "module-demo",
            "lesson_id": "bbbbbbbb-cccc-dddd-eeee-ffffffffffff",
            "pipeline_mode": "scene_orchestration_v1",
            "provider": "svd",
            "status": "failed",
            "playback_url": null,
            "error_message": "Upstream timeout after scene 2 render.",
            "client_app_version": "1.1.0",
            "created_at": "2026-04-28T11:45:00Z",
            "generation_prompt_excerpt": null
          }
        ]
        """#
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([LessonVideoRenderJobRow].self, from: data)) ?? []
    }
}
