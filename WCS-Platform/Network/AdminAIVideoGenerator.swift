//
//  AdminAIVideoGenerator.swift
//  WCS-Platform
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
}

struct VideoUploadSafetyReport: Codable, Hashable {
    let isUploadSafe: Bool
    let deliveryProtocol: String
    let mimeType: String
    let checksum: String
    let uploadStatus: String
    let rationale: String
}

protocol AIVideoGenerating {
    func cachedVideoAssets(for draft: AdminCourseDraft) async -> [UUID: GeneratedVideoAsset]
    func generateVideoAssets(
        for draft: AdminCourseDraft,
        onAssetGenerated: @escaping @Sendable (GeneratedVideoAsset) -> Void
    ) async -> [UUID: GeneratedVideoAsset]
    func clearCachedVideoAssets(for courseID: UUID) async
}

struct MockAIVideoGenerator: AIVideoGenerating {
    private let cache = GeneratedVideoAssetCache()
    nonisolated init() {}

    private let sampleVideoURLs = [
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4"
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
                try? await Task.sleep(nanoseconds: 600_000_000)

                let sourceHint = draft.sourceReferences.first ?? "internal curriculum guidance"
                let url = sampleVideoURLs[stableIndex(for: lesson.id, offset: seed) % sampleVideoURLs.count]
                seed += 1
                let scriptSegments = makeScriptSegments(for: lesson, module: module, draft: draft)
                let youtubeKeywords = makeYouTubeKeywords(for: lesson, module: module, draft: draft)
                let audioReadiness = AudioPresentationReadiness.snapshot()
                let youtubeURL = makeYouTubeSearchURL(keywords: youtubeKeywords)
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
                let uploadSafety = makeUploadSafetyReport(playbackURL: url, lesson: lesson)
                let apiPipeline = makeAPIPipeline()

                let asset = GeneratedVideoAsset(
                    lessonId: lesson.id,
                    title: lesson.title,
                    playbackURL: url,
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
                    Upload safety: \(uploadSafety.uploadStatus) (\(uploadSafety.rationale))
                    """,
                    confidence: draft.sourceReferences.isEmpty ? 0.65 : 0.86,
                    generatedAt: Date(),
                    youtubeCompanionURL: youtubeURL,
                    youtubeSearchKeywords: youtubeKeywords,
                    moduleScriptSegments: scriptSegments,
                    tutorialNarrationText: narration,
                    microphoneChecklist: audioReadiness.microphoneChecklist,
                    audioSystemStatus: audioReadiness.audioSystemStatus,
                    openAIRecommendedPipeline: apiPipeline,
                    moduleSyllabus: syllabus,
                    lecturePresentationOutline: lectureOutline,
                    uploadSafetyReport: uploadSafety
                )
                assets[lesson.id] = asset
                await cache.upsert(asset: asset, for: draft.id)
                onAssetGenerated(asset)
            }
        }

        return assets
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
            "POST /v1/videos (sora-2 or sora-2-pro) for generated lesson video jobs",
            "GET /v1/videos/{id} polling then GET /v1/videos/{id}/content for MP4 retrieval",
            "POST /v1/audio/speech for narration (gpt-4o-mini-tts)",
            "POST /v1/audio/transcriptions for microphone transcript QA (gpt-4o-transcribe)",
            "Use signed HTTPS object-storage upload endpoint for MP4 persistence (production backend)",
            "Validate MIME type, checksum, and moderation policy before module publication"
        ]
    }

    private func makeUploadSafetyReport(playbackURL: String, lesson: AdminLessonDraft) -> VideoUploadSafetyReport {
        let isHTTPS = playbackURL.lowercased().hasPrefix("https://")
        let mimeType = "video/mp4"
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
