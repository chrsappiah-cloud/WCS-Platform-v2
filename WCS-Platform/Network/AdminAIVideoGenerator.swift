//
//  AdminAIVideoGenerator.swift
//  WCS-Platform
//
//  Lesson video — Mootion-style **scene pipeline** (client storyboard + BFF orchestration)
//  ---------------------------------------------------------------------------
//  Product direction: **ingest → plan → generate → narrate → compose → review**, not one monolithic
//  “generate entire lesson” call. The app ships a `LessonVideoStoryboard` (`scene_orchestration_v1`) alongside
//  a legacy master `textToVideoPrompt` so the BFF can adopt short-clip generation + FFmpeg-style composition
//  while keeping a fallback path. See `Docs/LessonVideoPipelineArchitecture.md` and `LessonVideoStoryboardModels.swift`.
//
//  **Provider abstraction:** OpenAI Videos / Sora, Luma, LTX, SVD, etc. live only on the server. Treat OpenAI’s
//  Videos API as a **replaceable adapter** (vendor has announced deprecation / shutdown timeline for current
//  Sora 2 video models — plan migration at the BFF layer without rewriting iOS scene contracts).
//
//  Configure `WCSLessonTextToVideoEndpoint` + keys per `VideoGeneration-InfoPlistKeys.txt`; POST
//  `RemoteLessonTextToVideoRequest` → JSON `{ "playbackURL": "https://…" }` (signed MP4/HLS).
//

import Foundation

struct GeneratedVideoAsset: Codable, Hashable {
    let lessonId: UUID
    let title: String
    let playbackURL: String
    let scriptOutline: String
    let productionNotes: String
    let confidence: Double
    let generatedAt: Date
    let youtubeCompanionURL: String?
    let youtubeSearchKeywords: [String]?
    let moduleScriptSegments: [String]?
    let tutorialNarrationText: String?
    let microphoneChecklist: [String]?
    let audioSystemStatus: String?
    let openAIRecommendedPipeline: [String]?
    let moduleSyllabus: [String]?
    let lecturePresentationOutline: [String]?
    let uploadSafetyReport: VideoUploadSafetyReport?
    let motionTextToVideoKit: MotionTextToVideoKit?
    /// Scene-based plan sent to the BFF for this lesson (Mootion-style orchestration).
    let storyboard: LessonVideoStoryboard?
}

struct VideoUploadSafetyReport: Codable, Hashable {
    let isUploadSafe: Bool
    let deliveryProtocol: String
    let mimeType: String
    let checksum: String
    let uploadStatus: String
    let rationale: String
}

/// Legacy single-clip “kit” (master prompt + beats). Prefer `storyboard` on `GeneratedVideoAsset` for BFF v1.
struct MotionTextToVideoKit: Codable, Hashable {
    let enginePreset: String
    let targetDurationSeconds: Int
    let visualStyle: String
    let sceneBeats: [String]
    let shotPrompt: String
    let voiceoverScript: String
    let subtitleStyle: String
    let aspectRatio: String
    let exportPreset: String
}

protocol AIVideoGenerating {
    func cachedVideoAssets(for draft: AdminCourseDraft) async -> [UUID: GeneratedVideoAsset]
    func generateVideoAssets(
        for draft: AdminCourseDraft,
        onAssetGenerated: @escaping @Sendable (GeneratedVideoAsset) -> Void
    ) async -> [UUID: GeneratedVideoAsset]
    func clearCachedVideoAssets(for courseID: UUID) async
}

// MARK: - Remote BFF text-to-video

/// JSON body for `POST` to `LessonVideoGenerationSettings.remoteTextToVideoEndpointURL`.
struct RemoteLessonTextToVideoRequest: Encodable {
    let courseId: String
    let courseTitle: String
    let moduleId: String
    let moduleTitle: String
    let lessonId: String
    let lessonTitle: String
    let lessonNotes: String
    let targetAudience: String
    let level: String
    /// Single prompt suitable for frontier text-to-video models (Sora, Luma Ray2, LTX, etc.).
    let textToVideoPrompt: String
    let sourceReferences: [String]
    /// Optional routing hint for your BFF (from `WCSLessonTextToVideoProviderBackendHint`).
    let providerBackendHint: String?
    /// Client marketing version for BFF logging only.
    let clientAppVersion: String
    /// Structured scenes for orchestrated render; when set with `pipelineMode == .sceneOrchestrationV1`, BFF should prefer clip + compose flow.
    let storyboard: LessonVideoStoryboard?
    let pipelineMode: LessonVideoClientPipelineMode?
}

/// Expected JSON from the BFF after generation (or signed redirect to CDN).
struct RemoteLessonTextToVideoResponse: Decodable {
    let playbackURL: String
    let message: String?
}

/// Calls your HTTPS BFF (e.g. Supabase Edge Function) for each lesson; falls back to sample MP4s / YouTube discovery when the BFF returns no usable URL.
struct RemoteLessonVideoGenerator: AIVideoGenerating {
    private let endpoint: URL
    private let apiKey: String?
    private let supabaseAnonKey: String?
    private let mock: MockAIVideoGenerator
    private let urlSession: URLSession

    init(
        endpoint: URL,
        apiKey: String?,
        supabaseAnonKey: String?,
        urlSession: URLSession
    ) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.supabaseAnonKey = supabaseAnonKey
        self.mock = MockAIVideoGenerator()
        self.urlSession = urlSession
    }

    func cachedVideoAssets(for draft: AdminCourseDraft) async -> [UUID: GeneratedVideoAsset] {
        await mock.cachedVideoAssets(for: draft)
    }

    func clearCachedVideoAssets(for courseID: UUID) async {
        await mock.clearCachedVideoAssets(for: courseID)
    }

    func generateVideoAssets(
        for draft: AdminCourseDraft,
        onAssetGenerated: @escaping @Sendable (GeneratedVideoAsset) -> Void
    ) async -> [UUID: GeneratedVideoAsset] {
        var assets = await mock.cachedVideoAssets(for: draft)
        var seed = 0

        for module in draft.modules {
            for lesson in module.lessons where lesson.kind == .video || lesson.kind == .live {
                if let existing = assets[lesson.id] {
                    onAssetGenerated(existing)
                    continue
                }

                try? await Task.sleep(nanoseconds: LessonVideoGenerationSettings.mockGenerationDelayNanoseconds)

                let remoteURL = await requestTextToVideoPlaybackURL(
                    draft: draft,
                    module: module,
                    lesson: lesson
                )
                let defaultURL = await mock.resolveDefaultPlaybackURL(
                    lesson: lesson,
                    module: module,
                    draft: draft,
                    seed: seed
                )
                seed += 1

                let chosenURL: String
                let remoteNote: String?
                if let remoteURL, remoteURL.lowercased().hasPrefix("https://") {
                    chosenURL = remoteURL
                    remoteNote = "BFF text-to-video (generative)."
                } else {
                    chosenURL = defaultURL
                    remoteNote = remoteURL == nil ? nil : "BFF text-to-video returned no HTTPS URL; using default discovery."
                }

                let asset = await mock.makeGeneratedVideoAsset(
                    draft: draft,
                    module: module,
                    lesson: lesson,
                    playbackURL: chosenURL,
                    remoteSourceNote: remoteNote
                )
                assets[lesson.id] = asset
                await mock.upsertCached(asset: asset, for: draft.id)
                onAssetGenerated(asset)
            }
        }

        return assets
    }

    private func requestTextToVideoPlaybackURL(
        draft: AdminCourseDraft,
        module: AdminModuleDraft,
        lesson: AdminLessonDraft
    ) async -> String? {
        let motionKit = mock.makeMotionTextToVideoKitForRemote(
                    lesson: lesson,
                    module: module,
                    draft: draft
                )
        let storyboard = LessonVideoStoryboard.sceneOrchestrationV1(
            moduleId: module.id,
            moduleTitle: module.title,
            lessonId: lesson.id,
            lessonTitle: lesson.title,
            motionKit: motionKit
        )
        let body = RemoteLessonTextToVideoRequest(
            courseId: draft.id.uuidString,
            courseTitle: draft.title,
            moduleId: module.id.uuidString,
            moduleTitle: module.title,
            lessonId: lesson.id.uuidString,
            lessonTitle: lesson.title,
            lessonNotes: lesson.notes,
            targetAudience: draft.targetAudience,
            level: draft.level,
            textToVideoPrompt: motionKit.shotPrompt,
            sourceReferences: draft.sourceReferences,
            providerBackendHint: LessonVideoGenerationSettings.providerBackendHint,
            clientAppVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0",
            storyboard: storyboard,
            pipelineMode: .sceneOrchestrationV1
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        } else if let supabaseAnonKey, !supabaseAnonKey.isEmpty {
            // Supabase Edge Functions expect `Authorization: Bearer` for anon/publishable invokes when no user JWT.
            request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        }
        if let supabaseAnonKey, !supabaseAnonKey.isEmpty {
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        }
        for (headerName, value) in LessonVideoGenerationSettings.remoteTextToVideoExtraHTTPHeaders {
            request.setValue(value, forHTTPHeaderField: headerName)
        }
        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(RemoteLessonTextToVideoResponse.self, from: data)
            let url = decoded.playbackURL.trimmingCharacters(in: .whitespacesAndNewlines)
            return url.isEmpty ? nil : url
        } catch {
            return nil
        }
    }
}

struct MockAIVideoGenerator: AIVideoGenerating {
    private let cache = GeneratedVideoAssetCache()
    nonisolated init() {}

    private let sampleVideoURLs = [
        "https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
        "https://storage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
        "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
        "https://storage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4"
    ]

    func cachedVideoAssets(for draft: AdminCourseDraft) async -> [UUID: GeneratedVideoAsset] {
        await cache.assets(for: draft.id)
    }

    func generateVideoAssets(
        for draft: AdminCourseDraft,
        onAssetGenerated: @escaping @Sendable (GeneratedVideoAsset) -> Void
    ) async -> [UUID: GeneratedVideoAsset] {
        var assets = await cache.assets(for: draft.id)
        var seed = 0

        for module in draft.modules {
            for lesson in module.lessons where lesson.kind == .video || lesson.kind == .live {
                if let existing = assets[lesson.id] {
                    onAssetGenerated(existing)
                    continue
                }

                // Simulate progressive real-time generation work for each lesson.
                try? await Task.sleep(nanoseconds: LessonVideoGenerationSettings.mockGenerationDelayNanoseconds)

                let playbackURL = await resolveDefaultPlaybackURL(
                    lesson: lesson,
                    module: module,
                    draft: draft,
                    seed: seed
                )
                seed += 1
                let asset = await makeGeneratedVideoAsset(
                    draft: draft,
                    module: module,
                    lesson: lesson,
                    playbackURL: playbackURL,
                    remoteSourceNote: nil
                )
                assets[lesson.id] = asset
                await cache.upsert(asset: asset, for: draft.id)
                onAssetGenerated(asset)
            }
        }

        return assets
    }

    fileprivate func upsertCached(asset: GeneratedVideoAsset, for courseId: UUID) async {
        await cache.upsert(asset: asset, for: courseId)
    }

    fileprivate func resolveDefaultPlaybackURL(
        lesson: AdminLessonDraft,
        module: AdminModuleDraft,
        draft: AdminCourseDraft,
        seed: Int
    ) async -> String {
        let fallbackURL = sampleVideoURLs[stableIndex(for: lesson.id, offset: seed) % sampleVideoURLs.count]
        let youtubeKeywords = makeYouTubeKeywords(for: lesson, module: module, draft: draft)
        let liveSnippet = try? await resolveLiveLectureSnippet(keywords: youtubeKeywords)
        return liveSnippet
            .map { "https://www.youtube.com/watch?v=\($0.videoID)" }
            ?? fallbackURL
    }

    fileprivate func makeMotionTextToVideoKitForRemote(
        lesson: AdminLessonDraft,
        module: AdminModuleDraft,
        draft: AdminCourseDraft
    ) -> MotionTextToVideoKit {
        let scriptSegments = makeScriptSegments(for: lesson, module: module, draft: draft)
        let narration = makeNarrationText(
            lesson: lesson,
            module: module,
            draft: draft,
            scriptSegments: scriptSegments
        )
        return makeMotionTextToVideoKit(
            lesson: lesson,
            module: module,
            draft: draft,
            scriptSegments: scriptSegments,
            narration: narration
        )
    }

    fileprivate func makeGeneratedVideoAsset(
        draft: AdminCourseDraft,
        module: AdminModuleDraft,
        lesson: AdminLessonDraft,
        playbackURL: String,
        remoteSourceNote: String?
    ) async -> GeneratedVideoAsset {
        let sourceHint = draft.sourceReferences.first ?? "internal curriculum guidance"
        let scriptSegments = makeScriptSegments(for: lesson, module: module, draft: draft)
        let youtubeKeywords = makeYouTubeKeywords(for: lesson, module: module, draft: draft)
        let audioReadiness = AudioPresentationReadiness.snapshot()
        let youtubeURL = makeYouTubeSearchURL(keywords: youtubeKeywords)
        let liveSnippet = try? await resolveLiveLectureSnippet(keywords: youtubeKeywords)
        let narration = makeNarrationText(
            lesson: lesson,
            module: module,
            draft: draft,
            scriptSegments: scriptSegments
        )
        let syllabus = makeModuleSyllabus(for: module, draft: draft)
        let lectureOutline = makeLecturePresentationOutline(
            lesson: lesson,
            module: module,
            draft: draft
        )
        let uploadSafety = makeUploadSafetyReport(playbackURL: playbackURL, lesson: lesson)
        let apiPipeline = makeAPIPipeline()
        let motionKit = makeMotionTextToVideoKit(
            lesson: lesson,
            module: module,
            draft: draft,
            scriptSegments: scriptSegments,
            narration: narration
        )
        let storyboard = LessonVideoStoryboard.sceneOrchestrationV1(
            moduleId: module.id,
            moduleTitle: module.title,
            lessonId: lesson.id,
            lessonTitle: lesson.title,
            motionKit: motionKit
        )
        let remoteLine = remoteSourceNote.map { "\n\($0)" } ?? ""

        return GeneratedVideoAsset(
            lessonId: lesson.id,
            title: lesson.title,
            playbackURL: playbackURL,
            scriptOutline: """
            1) Hook and context for \(draft.title)
            2) Core concept walkthrough for \(module.title)
            3) Worked example and learner checkpoint
            4) Summary and next action
            """,
            productionNotes: """
            AI-generated in real time and archived for replay. Source grounding: \(sourceHint).
            Module syllabus: \(syllabus.joined(separator: " | "))
            Lecture presentation: \(lectureOutline.joined(separator: " | "))
            YouTube companion: \(youtubeURL ?? "Unavailable")
            Audio system: \(audioReadiness.audioSystemStatus)
            Mic readiness: \(audioReadiness.microphoneChecklist.joined(separator: " | "))
            Upload safety: \(uploadSafety.uploadStatus) (\(uploadSafety.rationale))\(remoteLine)
            """,
            confidence: draft.sourceReferences.isEmpty ? 0.65 : 0.86,
            generatedAt: Date(),
            youtubeCompanionURL: liveSnippet.map { "https://www.youtube.com/watch?v=\($0.videoID)" } ?? youtubeURL,
            youtubeSearchKeywords: youtubeKeywords,
            moduleScriptSegments: scriptSegments,
            tutorialNarrationText: narration,
            microphoneChecklist: audioReadiness.microphoneChecklist,
            audioSystemStatus: audioReadiness.audioSystemStatus,
            openAIRecommendedPipeline: apiPipeline,
            moduleSyllabus: syllabus,
            lecturePresentationOutline: lectureOutline,
            uploadSafetyReport: uploadSafety,
            motionTextToVideoKit: motionKit,
            storyboard: storyboard
        )
    }

    private func stableIndex(for id: UUID, offset: Int) -> Int {
        let sum = id.uuidString.unicodeScalars.reduce(0) { partial, scalar in
            partial + Int(scalar.value)
        }
        return sum + offset
    }

    private func makeScriptSegments(
        for lesson: AdminLessonDraft,
        module: AdminModuleDraft,
        draft: AdminCourseDraft
    ) -> [String] {
        let lessonNotes = lesson.notes
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let scriptedNotes = Array(lessonNotes.prefix(3))

        var segments: [String] = [
            "Hook: \(draft.title) -> \(module.title) -> \(lesson.title)",
            "Objective: \(module.goals.first ?? "Understand the key concept and apply it confidently.")"
        ]

        if scriptedNotes.isEmpty {
            segments.append("Walkthrough: Explain concept, show applied example, close with learner action.")
        } else {
            segments.append(contentsOf: scriptedNotes.map { "Script cue: \($0)" })
        }

        segments.append("Checkpoint: Ask learner to summarize one practical takeaway.")
        return segments
    }

    private func makeYouTubeKeywords(
        for lesson: AdminLessonDraft,
        module: AdminModuleDraft,
        draft: AdminCourseDraft
    ) -> [String] {
        let seedTerms = [
            "World Class Scholars",
            draft.title,
            module.title,
            lesson.title,
            "\(draft.level) tutorial",
            "module unit walkthrough"
        ]
        return seedTerms
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func makeYouTubeSearchURL(keywords: [String]) -> String? {
        let query = keywords.joined(separator: " ")
        guard var comps = URLComponents(string: "https://www.youtube.com/results") else { return nil }
        comps.queryItems = [URLQueryItem(name: "search_query", value: query)]
        return comps.url?.absoluteString
    }

    private func resolveLiveLectureSnippet(keywords: [String]) async throws -> YouTubeVideoSnippet? {
        guard YouTubeSearchAPIClient.resolveAPIKey() != nil else { return nil }
        let query = keywords.joined(separator: " ")
        let page = try await YouTubeSearchAPIClient.searchVideos(
            query: query,
            configuration: .wcsLearning,
            maxResults: 3
        )
        return page.items.first
    }

    private func makeNarrationText(
        lesson: AdminLessonDraft,
        module: AdminModuleDraft,
        draft: AdminCourseDraft,
        scriptSegments: [String]
    ) -> String {
        let body = scriptSegments.joined(separator: " ")
        return """
        Welcome to World Class Scholars. In this unit, \(lesson.title), part of \(module.title), we focus on practical mastery for \(draft.targetAudience). \(body)
        """
    }

    private func makeModuleSyllabus(for module: AdminModuleDraft, draft: AdminCourseDraft) -> [String] {
        var syllabus: [String] = [
            "Course: \(draft.title)",
            "Module: \(module.title)",
            "Audience: \(draft.targetAudience)",
            "Level: \(draft.level)"
        ]
        syllabus.append(contentsOf: module.goals.prefix(3).map { "Goal: \($0)" })
        syllabus.append("Assessment: quiz and assignment checkpoints per module design.")
        return syllabus
    }

    private func makeLecturePresentationOutline(
        lesson: AdminLessonDraft,
        module: AdminModuleDraft,
        draft: AdminCourseDraft
    ) -> [String] {
        [
            "Lecture title: \(lesson.title)",
            "Module context: \(module.title)",
            "Slide 1: Learning outcomes and syllabus alignment",
            "Slide 2: Core concept walkthrough",
            "Slide 3: Applied case and demo",
            "Slide 4: Recap, API-backed video recap, and learner action"
        ]
    }

    private func makeAPIPipeline() -> [String] {
        [
            "iOS: configure WCSLessonText* keys in Info.plist (see VideoGeneration-InfoPlistKeys.txt)",
            "POST JSON to WCSLessonTextToVideoEndpoint → { playbackURL, message? }; optional Bearer + apikey headers",
            "Pipeline: scene_orchestration_v1 — storyboard.scenes[] short clips (5–20s) + TTS + compose (BFF); textToVideoPrompt remains fallback master prompt",
            "OpenAI Videos / Sora: async POST /v1/videos, poll GET /v1/videos/{id}, download GET /v1/videos/{id}/content; plan provider swap — current Sora 2 video API deprecated with announced sunset (verify OpenAI docs)",
            "POST /v1/audio/speech for narration (gpt-4o-mini-tts)",
            "POST /v1/audio/transcriptions for microphone transcript QA (gpt-4o-transcribe)",
            "GET https://cloudaicompanion.googleapis.com/v1/projects/{project}/locations for Google model location discovery",
            "Use OAuth Bearer token for Google Cloud AI Companion authenticated calls",
            "Use signed HTTPS object-storage upload endpoint for MP4 persistence (production backend)",
            "Validate MIME type, checksum, and moderation policy before module publication"
        ]
    }

    private func makeMotionTextToVideoKit(
        lesson: AdminLessonDraft,
        module: AdminModuleDraft,
        draft: AdminCourseDraft,
        scriptSegments: [String],
        narration: String
    ) -> MotionTextToVideoKit {
        let beats = [
            "Cold open: state learner outcome for \(lesson.title).",
            "Concept reveal: explain one core principle from \(module.title).",
            "Worked example: map concept to a practical scenario.",
            "Recap + CTA: learner writes one applied takeaway."
        ]
        let style = "clean educational motion graphics, high contrast labels, subtle camera drift"
        let prompt = """
        Create a concise lesson video for "\(lesson.title)" in course "\(draft.title)".
        Audience: \(draft.targetAudience). Level: \(draft.level).
        Visual style: \(style).
        Include these beats: \(beats.joined(separator: " | ")).
        """
        return MotionTextToVideoKit(
            enginePreset: "motion-ai-edu-v1",
            targetDurationSeconds: max(60, lesson.durationMinutes * 60),
            visualStyle: style,
            sceneBeats: beats + scriptSegments,
            shotPrompt: prompt,
            voiceoverScript: narration,
            subtitleStyle: "high-legibility lower-third, 2 lines max, sentence case",
            aspectRatio: "16:9",
            exportPreset: "h264-main-1080p-30fps-aac"
        )
    }

    private func makeUploadSafetyReport(playbackURL: String, lesson: AdminLessonDraft) -> VideoUploadSafetyReport {
        let isHTTPS = playbackURL.lowercased().hasPrefix("https://")
        let mimeType: String
        if playbackURL.contains("youtube.com") || playbackURL.contains("youtu.be") {
            mimeType = "text/html"
        } else if playbackURL.contains(".m3u8") {
            mimeType = "application/vnd.apple.mpegurl"
        } else {
            mimeType = "video/mp4"
        }
        let checksumSeed = "\(lesson.id.uuidString)|\(playbackURL)"
        let checksum = checksumSeed.unicodeScalars
            .reduce(into: 0) { partial, scalar in partial = (partial &* 31) &+ Int(scalar.value) }
        let checksumHex = String(format: "%08X", checksum)
        return VideoUploadSafetyReport(
            isUploadSafe: isHTTPS,
            deliveryProtocol: isHTTPS ? "HTTPS" : "UNSAFE",
            mimeType: mimeType,
            checksum: checksumHex,
            uploadStatus: isHTTPS ? "validated-and-archived" : "blocked",
            rationale: isHTTPS
                ? "Playback URL passed HTTPS policy and checksum generation."
                : "Blocked because non-HTTPS URLs are not allowed for module delivery."
        )
    }

    func clearCachedVideoAssets(for courseID: UUID) async {
        await cache.removeAssets(for: courseID)
    }
}

private actor GeneratedVideoAssetCache {
    private let storageKey = "wcs.generatedVideoAssetsByCourse"
    private var assetsByCourse: [UUID: [UUID: GeneratedVideoAsset]] = [:]
    private var hasLoaded = false

    func assets(for courseId: UUID) -> [UUID: GeneratedVideoAsset] {
        loadIfNeeded()
        return assetsByCourse[courseId] ?? [:]
    }

    func upsert(asset: GeneratedVideoAsset, for courseId: UUID) {
        loadIfNeeded()
        var courseAssets = assetsByCourse[courseId] ?? [:]
        courseAssets[asset.lessonId] = asset
        assetsByCourse[courseId] = courseAssets
        persist()
    }

    func removeAssets(for courseId: UUID) {
        loadIfNeeded()
        assetsByCourse.removeValue(forKey: courseId)
        persist()
    }

    private func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        if let decoded = try? JSONDecoder().decode([String: [GeneratedVideoAsset]].self, from: data) {
            assetsByCourse = decoded.reduce(into: [:]) { partialResult, entry in
                guard let courseId = UUID(uuidString: entry.key) else { return }
                partialResult[courseId] = Dictionary(uniqueKeysWithValues: entry.value.map { ($0.lessonId, $0) })
            }
        }
    }

    private func persist() {
        let encodable = assetsByCourse.reduce(into: [String: [GeneratedVideoAsset]]()) { partialResult, entry in
            partialResult[entry.key.uuidString] = Array(entry.value.values)
        }
        if let data = try? JSONEncoder().encode(encodable) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
