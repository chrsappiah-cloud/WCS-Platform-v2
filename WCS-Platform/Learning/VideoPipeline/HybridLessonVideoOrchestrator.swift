//
//  HybridLessonVideoOrchestrator.swift
//  WCS-Platform
//
//  Coordinates Apple on-device Foundation Models + Image Playground with OpenAI Sora
//  (via Supabase BFF) for lesson video generation.
//

import Foundation

struct HybridLessonVideoOrchestrator {
    private let appleService = AppleFoundationLessonVideoService()
    private let imageSequenceRenderer = AVFoundationImageSequenceRenderer()
    private let lessonComposer = AVFoundationLessonComposer()

    /// Plans a storyboard using Apple Foundation Models when available; falls back to network mock/API.
    func planStoryboard(_ request: LessonVideoPlanRequest) async throws -> (storyboard: LessonVideoStoryboard, source: String) {
        let availability = AppleFoundationLessonVideoService.availabilitySnapshot()
        if availability.isStoryboardPlanningAvailable {
            do {
                let storyboard = try await appleService.planStoryboard(request: request)
                return (storyboard, "Apple Foundation Models (on-device)")
            } catch {
                // Fall through to network heuristic when FM fails at runtime.
            }
        }

        let planned = try await NetworkClient.shared.planLessonVideo(request)
        let source = availability.isStoryboardPlanningAvailable
            ? "Network fallback (Apple FM unavailable at runtime)"
            : "Network heuristic (Apple FM offline)"
        return (planned.storyboard, source)
    }

    /// Hybrid render: OpenAI/Sora via BFF when configured; otherwise on-device image-sequence path.
    func renderFirstScene(
        draft: AdminCourseDraft,
        module: AdminModuleDraft,
        lesson: AdminLessonDraft,
        storyboard: LessonVideoStoryboard,
        scene: LessonVideoScenePlan,
        settings: ImageSequenceRenderSettings
    ) async throws -> (clipURL: URL, source: String) {
        if LessonVideoGenerationSettings.isRemoteTextToVideoEnabled,
           LessonVideoGenerationSettings.generationApproach != .onDeviceExperimental,
           ProcessInfo.processInfo.environment["WCS_UI_TEST_LOCAL_VIDEO_ONLY"] != "1" {
            if let remoteURL = await RemoteLessonVideoClient.requestPlaybackURL(
                draft: draft,
                module: module,
                lesson: lesson,
                storyboard: storyboard
            ), remoteURL.isFileURL || remoteURL.scheme?.lowercased() == "https" {
                return (remoteURL, "OpenAI Sora via Supabase BFF")
            }
        }

        var enrichedScene = scene
        if AppleFoundationLessonVideoService.availabilitySnapshot().isReferenceImageGenerationAvailable {
            var enrichedBoard = storyboard
            enrichedBoard.scenes = [scene]
            let enriched = try await appleService.enrichStoryboardWithReferenceImages(enrichedBoard)
            if let first = enriched.scenes.first {
                enrichedScene = first
            }
        }

        let localClip = try await imageSequenceRenderer.renderSceneClip(scene: enrichedScene, settings: settings)
        return (localClip, "Apple Image Playground + AVFoundation image-sequence")
    }

    /// Full on-device lesson: enrich all scenes with Image Playground, render clips, compose locally.
    func renderOnDeviceLesson(
        storyboard: LessonVideoStoryboard,
        settings: ImageSequenceRenderSettings = .default
    ) async throws -> URL {
        let enriched = try await appleService.enrichStoryboardWithReferenceImages(storyboard)
        return try await appleService.renderOnDeviceLesson(storyboard: enriched, settings: settings)
    }

    func composeAvailableClips(
        generatedAssets: [GeneratedVideoAsset],
        localImageClip: URL?,
        localComposed: URL?
    ) async throws -> URL {
        if let localComposed {
            return localComposed
        }

        var clipURLs: [URL] = generatedAssets
            .compactMap { URL(string: $0.playbackURL) }
            .filter {
                LessonVideoPlaybackPolicy.isNativeAVPlayerHTTPSURL($0) &&
                LessonVideoSafetyPolicy.validatePlaybackURLString($0.absoluteString) == nil
            }
        if let localImageClip {
            clipURLs.append(localImageClip)
        }
        guard !clipURLs.isEmpty else {
            throw HybridLessonVideoError.noClipsAvailable
        }
        return try await lessonComposer.composeLesson(clips: clipURLs)
    }
}

enum HybridLessonVideoError: LocalizedError {
    case noClipsAvailable

    var errorDescription: String? {
        switch self {
        case .noClipsAvailable:
            return "No HTTPS or local clips available to compose."
        }
    }
}

/// Shared remote OpenAI/Sora client used by bulk generation and hybrid scene render.
enum RemoteLessonVideoClient {
    static func requestPlaybackURL(
        draft: AdminCourseDraft,
        module: AdminModuleDraft,
        lesson: AdminLessonDraft,
        storyboard: LessonVideoStoryboard? = nil
    ) async -> URL? {
        guard let endpoint = LessonVideoGenerationSettings.remoteTextToVideoEndpointURL else {
            return nil
        }

        let mock = MockAIVideoGenerator()
        let motionKit = mock.makeMotionTextToVideoKitForRemote(
            lesson: lesson,
            module: module,
            draft: draft
        )
        var resolvedStoryboard = storyboard ?? LessonVideoStoryboard.sceneOrchestrationV1(
            moduleId: module.id,
            moduleTitle: module.title,
            lessonId: lesson.id,
            lessonTitle: lesson.title,
            motionKit: motionKit
        )
        resolvedStoryboard.ensureStructuredPlansForAllScenes(stylePreset: draft.level)

        let body = RemoteLessonTextToVideoRequest(
            courseId: draft.id.uuidString,
            courseTitle: draft.title,
            moduleId: module.id.uuidString,
            moduleTitle: module.title,
            lessonId: lesson.id.uuidString,
            lessonTitle: lesson.title,
            lessonNotes: lesson.notes,
            sourceScript: cleanLessonScript(lesson: lesson, module: module, draft: draft),
            targetAudience: draft.targetAudience,
            level: draft.level,
            textToVideoPrompt: resolvedStoryboard.masterVisualPrompt ?? motionKit.shotPrompt,
            sourceReferences: draft.sourceReferences,
            providerBackendHint: LessonVideoGenerationSettings.effectiveProviderBackendHint,
            clientAppVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0",
            storyboard: resolvedStoryboard,
            pipelineMode: .sceneOrchestrationV1,
            sceneBreakdownProvider: "openai_gpt41"
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = LessonVideoGenerationSettings.remoteTextToVideoBearerToken, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        } else if let supabaseAnonKey = LessonVideoGenerationSettings.remoteTextToVideoSupabaseAnonKey, !supabaseAnonKey.isEmpty {
            request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        }
        if let supabaseAnonKey = LessonVideoGenerationSettings.remoteTextToVideoSupabaseAnonKey, !supabaseAnonKey.isEmpty {
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        }
        for (headerName, value) in LessonVideoGenerationSettings.remoteTextToVideoExtraHTTPHeaders {
            request.setValue(value, forHTTPHeaderField: headerName)
        }

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let session = LessonVideoGenerationSettings.makeURLSessionForTextToVideo()
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                await RemoteLessonVideoDiagnostics.shared.recordFailure("Invalid HTTP response from BFF.")
                return nil
            }
            guard (200...299).contains(http.statusCode) else {
                let bodyText = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
                await RemoteLessonVideoDiagnostics.shared.recordFailure("HTTP \(http.statusCode): \(bodyText)")
                return nil
            }
            let decoded: RemoteLessonTextToVideoResponse
            do {
                decoded = try JSONDecoder().decode(RemoteLessonTextToVideoResponse.self, from: data)
            } catch {
                let bodyText = String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
                await RemoteLessonVideoDiagnostics.shared.recordFailure(
                    "Decode failed: \(error.localizedDescription). Body: \(bodyText)"
                )
                return nil
            }
            let trimmed = decoded.playbackURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let url = URL(string: trimmed) else {
                await RemoteLessonVideoDiagnostics.shared.recordFailure("BFF returned empty playbackURL.")
                return nil
            }
            if let rejection = LessonVideoSafetyPolicy.validateGeneratedLessonVideoURL(url) {
                await RemoteLessonVideoDiagnostics.shared.recordFailure("BFF returned rejected playbackURL: \(rejection)")
                return nil
            }
            await RemoteLessonVideoDiagnostics.shared.recordSuccess(url.absoluteString, message: decoded.message)
            return url
        } catch {
            await RemoteLessonVideoDiagnostics.shared.recordFailure(error.localizedDescription)
            return nil
        }
    }

    private static func cleanLessonScript(
        lesson: AdminLessonDraft,
        module: AdminModuleDraft,
        draft: AdminCourseDraft
    ) -> String {
        let cleaned = LessonManualVideoBackup.stripMachineLines(from: lesson.notes)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty {
            return cleaned
        }
        return """
        \(lesson.title). Module: \(module.title). Course: \(draft.title).
        Learning outcomes: \(draft.outcomes.joined(separator: "; ")).
        Explain core concepts with clear examples suitable for \(draft.targetAudience).
        """
    }
}

actor RemoteLessonVideoDiagnostics {
    static let shared = RemoteLessonVideoDiagnostics()

    private(set) var lastSuccessURL: String?
    private(set) var lastMessage: String?
    private(set) var lastFailure: String?
    private(set) var lastCheckedAt: Date?

    func recordSuccess(_ url: String, message: String?) {
        lastSuccessURL = url
        lastMessage = message
        lastFailure = nil
        lastCheckedAt = Date()
    }

    func recordFailure(_ detail: String) {
        lastFailure = detail
        lastCheckedAt = Date()
    }

    func snapshot() -> (successURL: String?, message: String?, failure: String?, checkedAt: Date?) {
        (lastSuccessURL, lastMessage, lastFailure, lastCheckedAt)
    }

    func conciseStatus() -> String {
        if let lastSuccessURL {
            return "last success \(lastSuccessURL)"
        }
        if let lastFailure {
            return String(lastFailure.prefix(280))
        }
        return "no remote attempt recorded"
    }
}
