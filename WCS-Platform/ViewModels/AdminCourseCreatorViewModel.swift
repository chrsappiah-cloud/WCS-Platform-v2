//
//  AdminCourseCreatorViewModel.swift
//  WCS-Platform
//

import Combine
import Foundation

@MainActor
final class AdminCourseCreatorViewModel: ObservableObject {
    private struct CreatorDefaults: Codable {
        var selectedAccessTier: AdminCourseAccessTier
        var productName: String
        var idealLearner: String
        var transformation: String
        var offerStack: String
        var launchAngle: String
        var selectedCohortType: AICohortType
        var preferredCohortSize: String
        var prompt: String
        var manualCourseTitle: String
        var manualSummary: String
        var manualModuleTitle: String
        var manualVideoTitle: String
        var manualVideoURL: String
        var manualReadingTitle: String
        var manualReadingMaterial: String
        var manualQuizTitle: String
        var manualQuizPrompt: String
        var manualAssignmentTitle: String
        var manualAssignmentBrief: String
    }

    private static let creatorDefaultsKey = "wcs.admin.creator.defaults.v1"

    struct DraftVideoStatus: Hashable {
        let totalVideoLessons: Int
        let generatedVideoLessons: Int
        let isGenerating: Bool
        let latestGeneratedAt: Date?
    }

    @Published var accessCodeInput = ""
    @Published var isUnlocked = false
    @Published var prompt = ""
    @Published var selectedAccessTier: AdminCourseAccessTier = .freePublic
    @Published var productName = ""
    @Published var idealLearner = ""
    @Published var transformation = ""
    @Published var offerStack = ""
    @Published var launchAngle = ""
    @Published var selectedCohortType: AICohortType = .weeklyCohort
    @Published var preferredCohortSize = "30"
    @Published var manualCourseTitle = ""
    @Published var manualSummary = ""
    @Published var manualModuleTitle = ""
    @Published var manualVideoTitle = ""
    @Published var manualVideoURL = ""
    @Published var manualReadingTitle = ""
    @Published var manualReadingMaterial = ""
    @Published var manualQuizTitle = ""
    @Published var manualQuizPrompt = ""
    @Published var manualAssignmentTitle = ""
    @Published var manualAssignmentBrief = ""
    @Published var isGenerating = false
    @Published var drafts: [AdminCourseDraft] = []
    @Published var videoStatusByDraftID: [UUID: DraftVideoStatus] = [:]
    @Published var generatedAssetsByDraftID: [UUID: [GeneratedVideoAsset]] = [:]
    @Published var errorMessage: String?
    /// Supabase Edge `wcs-lesson-video-jobs` (requires `WCSLessonVideoJobListSecret` + deployed function).
    @Published var lessonVideoRenderJobs: [LessonVideoRenderJobRow] = []
    @Published var lessonVideoJobsLoadError: String?
    @Published var pipelineStatusByDraftID: [UUID: String] = [:]
    @Published var pipelineBusyDraftIDs: Set<UUID> = []
    @Published var plannedStoryboardByDraftID: [UUID: LessonVideoStoryboard] = [:]
    @Published var localComposedVideoByDraftID: [UUID: URL] = [:]
    @Published var localImageSequenceClipByDraftID: [UUID: URL] = [:]
    @Published var localImageSequencePreviewByDraftID: [UUID: URL] = [:]
    @Published var imageSequenceSettingsByDraftID: [UUID: ImageSequenceRenderSettings] = [:]

    private let lessonComposer = AVFoundationLessonComposer()
    private let imageSequenceRenderer = AVFoundationImageSequenceRenderer()

    init() {
        loadSavedConfiguration()
    }

    func unlock() {
        guard !accessCodeInput.isEmpty else {
            errorMessage = "Enter admin access code."
            return
        }
        let expectedCode = {
            if let injected = ProcessInfo.processInfo.environment["WCS_UI_TEST_ADMIN_ACCESS_CODE"],
               !injected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return injected.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return AppEnvironment.adminAccessCode
        }()
        if accessCodeInput == expectedCode {
            isUnlocked = true
            errorMessage = nil
            UserDefaults.standard.set(true, forKey: "wcs.mockAdminMode")
            UserDefaults.standard.set(UserRole.orgAdmin.rawValue, forKey: "wcs.mockRole")
            NotificationCenter.default.post(name: .wcsLearningStateDidChange, object: nil)
        } else {
            errorMessage = "Invalid admin access code."
        }
    }

    func loadDrafts() async {
        await AdminCourseDraftStore.shared.deleteBlockedDraftsAndCourses()
        drafts = await AdminCourseDraftStore.shared.allDrafts()
        await refreshVideoStatuses()
    }

    func generate(createdBy: String) async {
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        do {
            saveCurrentAsDefaultConfiguration()
            let finalPrompt = buildKajabiStylePrompt()
            _ = try await AdminCourseDraftStore.shared.generate(
                prompt: finalPrompt,
                createdBy: createdBy,
                accessTier: selectedAccessTier
            )
            drafts = await AdminCourseDraftStore.shared.allDrafts()
            await refreshVideoStatuses()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createManualBackupDraft(createdBy: String) async {
        errorMessage = nil
        guard canCreateManualBackup else {
            errorMessage = "Complete all manual backup fields before creating draft."
            return
        }
        saveCurrentAsDefaultConfiguration()
        do {
            _ = try await AdminCourseDraftStore.shared.createManualBackupDraft(
                createdBy: createdBy,
                accessTier: selectedAccessTier,
                courseTitle: manualCourseTitle,
                summary: manualSummary,
                moduleTitle: manualModuleTitle,
                videoTitle: manualVideoTitle,
                videoURL: manualVideoURL,
                readingTitle: manualReadingTitle,
                readingMaterial: manualReadingMaterial,
                quizTitle: manualQuizTitle,
                quizPrompt: manualQuizPrompt,
                assignmentTitle: manualAssignmentTitle,
                assignmentBrief: manualAssignmentBrief
            )
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        clearManualBackupInputs()
        drafts = await AdminCourseDraftStore.shared.allDrafts()
        await refreshVideoStatuses()
    }

    func publish(_ id: UUID) async {
        errorMessage = nil
        do {
            try await AdminCourseDraftStore.shared.markPublished(id)
            drafts = await AdminCourseDraftStore.shared.allDrafts()
            await refreshVideoStatuses()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearAll() async {
        await AdminCourseDraftStore.shared.clearAll()
        drafts = await AdminCourseDraftStore.shared.allDrafts()
        videoStatusByDraftID = [:]
        generatedAssetsByDraftID = [:]
    }

    func regenerateVideos(for draftID: UUID, clearCache: Bool) async {
        guard let draft = drafts.first(where: { $0.id == draftID }) else { return }
        await MockLearningStore.shared.regenerateVideoAssets(for: draft, clearCache: clearCache)
        await refreshVideoStatuses()
        await loadLessonVideoRenderJobs()
    }

    func saveManualLessonVideoBackup(
        draftID: UUID,
        moduleID: UUID,
        lessonID: UUID,
        url: String,
        externalVideoSource: ExternalLessonVideoSource
    ) async {
        errorMessage = nil
        do {
            let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
            try await AdminCourseDraftStore.shared.setManualLessonVideoPlaybackURL(
                draftId: draftID,
                moduleId: moduleID,
                lessonId: lessonID,
                urlString: url,
                externalVideoSource: trimmedURL.isEmpty ? nil : externalVideoSource
            )
            drafts = await AdminCourseDraftStore.shared.allDrafts()
            await refreshVideoStatuses()
            NotificationCenter.default.post(name: .wcsLearningStateDidChange, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func planStoryboard(for draftID: UUID) async {
        guard let draft = drafts.first(where: { $0.id == draftID }),
              let (module, lesson) = firstVideoLesson(in: draft)
        else {
            errorMessage = "No video lesson found to plan."
            return
        }
        pipelineBusyDraftIDs.insert(draftID)
        defer { pipelineBusyDraftIDs.remove(draftID) }
        do {
            let req = LessonVideoPlanRequest(
                lessonId: lesson.id.uuidString,
                moduleId: module.id.uuidString,
                moduleTitle: module.title,
                lessonTitle: lesson.title,
                sourceScript: LessonManualVideoBackup.stripMachineLines(from: lesson.notes),
                learningObjectives: draft.outcomes,
                glossary: [],
                assessmentPrompts: [lesson.title],
                targetAgeBand: draft.level,
                styleProfileId: nil,
                referenceAssetIds: []
            )
            let planned = try await NetworkClient.shared.planLessonVideo(req)
            plannedStoryboardByDraftID[draftID] = planned.storyboard
            pipelineStatusByDraftID[draftID] = "Planned \(planned.storyboard.scenes.count) scene(s)"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            pipelineStatusByDraftID[draftID] = "Planning failed"
        }
    }

    func renderFirstPlannedScene(for draftID: UUID) async {
        guard let draft = drafts.first(where: { $0.id == draftID }),
              let storyboard = plannedStoryboardByDraftID[draftID],
              let scene = storyboard.scenes.first,
              let (module, lesson) = firstVideoLesson(in: draft)
        else {
            errorMessage = "Plan a storyboard before rendering scenes."
            return
        }
        pipelineBusyDraftIDs.insert(draftID)
        defer { pipelineBusyDraftIDs.remove(draftID) }
        do {
            let strategy = LessonVideoGenerationSettings.generationApproach
            if strategy == .onDeviceExperimental {
                pipelineStatusByDraftID[draftID] = "On-device video generation is experimental and not enabled in this build."
                errorMessage = "Switch strategy to hybrid or image-sequence for production rendering."
                return
            }
            if strategy == .imageSequenceAnimation {
                let settings = imageSequenceSettingsByDraftID[draftID] ?? .default
                let localClip = try await imageSequenceRenderer.renderSceneClip(scene: scene, settings: settings)
                localImageSequenceClipByDraftID[draftID] = localClip
                pipelineStatusByDraftID[draftID] = "Image-sequence clip rendered locally (\(settings.resolution.label), \(settings.fps) fps): \(localClip.lastPathComponent)"
                errorMessage = nil
                return
            }
            let req = LessonVideoSceneRenderRequest(
                lessonId: lesson.id.uuidString,
                moduleId: module.id.uuidString,
                moduleTitle: module.title,
                scene: scene,
                providerBackendHint: LessonVideoGenerationSettings.providerBackendHint
            )
            let job = try await NetworkClient.shared.renderLessonScene(scene.sceneId, request: req)
            pipelineStatusByDraftID[draftID] = "Render job \(job.renderJobId): \(job.normalizedStatus?.displayLabel ?? job.status)"
            errorMessage = nil
            await loadLessonVideoRenderJobs()
        } catch {
            errorMessage = error.localizedDescription
            pipelineStatusByDraftID[draftID] = "Render failed"
        }
    }

    func previewFirstPlannedScene(for draftID: UUID) async {
        guard let storyboard = plannedStoryboardByDraftID[draftID],
              let scene = storyboard.scenes.first
        else {
            errorMessage = "Plan a storyboard before previewing."
            return
        }
        pipelineBusyDraftIDs.insert(draftID)
        defer { pipelineBusyDraftIDs.remove(draftID) }
        do {
            let settings = imageSequenceSettingsByDraftID[draftID] ?? .default
            let preview = try await imageSequenceRenderer.renderPreviewFrame(scene: scene, settings: settings)
            localImageSequencePreviewByDraftID[draftID] = preview
            pipelineStatusByDraftID[draftID] = "Preview frame rendered: \(preview.lastPathComponent)"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            pipelineStatusByDraftID[draftID] = "Preview failed"
        }
    }

    func composePlannedLesson(for draftID: UUID) async {
        guard let draft = drafts.first(where: { $0.id == draftID }),
              let (_, lesson) = firstVideoLesson(in: draft)
        else {
            errorMessage = "No video lesson found to compose."
            return
        }
        pipelineBusyDraftIDs.insert(draftID)
        defer { pipelineBusyDraftIDs.remove(draftID) }
        do {
            let strategy = LessonVideoGenerationSettings.generationApproach
            if strategy == .onDeviceExperimental {
                pipelineStatusByDraftID[draftID] = "On-device composition path not configured for full text-to-video yet."
                errorMessage = "On-device experimental mode is currently limited."
                return
            }

            // Hybrid/image-sequence strategy: prefer native AVFoundation composition from available clips.
            var clipURLs: [URL] = (generatedAssetsByDraftID[draftID] ?? [])
                .compactMap { URL(string: $0.playbackURL) }
                .filter {
                    LessonVideoPlaybackPolicy.isNativeAVPlayerHTTPSURL($0) &&
                    LessonVideoSafetyPolicy.validatePlaybackURLString($0.absoluteString) == nil
                }
            if let localImageClip = localImageSequenceClipByDraftID[draftID] {
                clipURLs.append(localImageClip)
            }
            if !clipURLs.isEmpty {
                let output = try await lessonComposer.composeLesson(clips: clipURLs)
                localComposedVideoByDraftID[draftID] = output
                pipelineStatusByDraftID[draftID] = "Locally composed via AVFoundation: \(output.lastPathComponent)"
                errorMessage = nil
                return
            }

            let response = try await NetworkClient.shared.composeLessonVideo(
                lesson.id.uuidString,
                request: LessonVideoComposeRequest(
                    lessonId: lesson.id.uuidString,
                    moduleId: draft.modules.first?.id.uuidString,
                    includeCaptions: true,
                    includeChapterMarkers: true
                )
            )
            pipelineStatusByDraftID[draftID] = "Compose status: \(response.status)"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            pipelineStatusByDraftID[draftID] = "Compose failed"
        }
    }

    func applyTemplate(_ template: KajabiBlueprintTemplate) {
        productName = template.defaultProductName
        idealLearner = template.defaultLearner
        transformation = template.defaultTransformation
        offerStack = template.defaultOffer
        launchAngle = template.defaultLaunch
        prompt = template.defaultProductionNotes
    }

    func saveCurrentAsDefaultConfiguration() {
        let payload = CreatorDefaults(
            selectedAccessTier: selectedAccessTier,
            productName: productName,
            idealLearner: idealLearner,
            transformation: transformation,
            offerStack: offerStack,
            launchAngle: launchAngle,
            selectedCohortType: selectedCohortType,
            preferredCohortSize: preferredCohortSize,
            prompt: prompt,
            manualCourseTitle: manualCourseTitle,
            manualSummary: manualSummary,
            manualModuleTitle: manualModuleTitle,
            manualVideoTitle: manualVideoTitle,
            manualVideoURL: manualVideoURL,
            manualReadingTitle: manualReadingTitle,
            manualReadingMaterial: manualReadingMaterial,
            manualQuizTitle: manualQuizTitle,
            manualQuizPrompt: manualQuizPrompt,
            manualAssignmentTitle: manualAssignmentTitle,
            manualAssignmentBrief: manualAssignmentBrief
        )
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(payload) else {
            errorMessage = "Could not save default settings."
            return
        }
        UserDefaults.standard.set(data, forKey: Self.creatorDefaultsKey)
        errorMessage = nil
    }

    func resetSavedConfiguration() {
        UserDefaults.standard.removeObject(forKey: Self.creatorDefaultsKey)
        errorMessage = nil
    }

    func applySavedConfigurationIfAvailable() {
        loadSavedConfiguration()
    }

    var canGenerate: Bool {
        buildKajabiStylePrompt().trimmingCharacters(in: .whitespacesAndNewlines).count >= 20
    }

    var canCreateManualBackup: Bool {
        [
            manualCourseTitle,
            manualSummary,
            manualModuleTitle,
            manualVideoTitle,
            manualVideoURL,
            manualReadingTitle,
            manualReadingMaterial,
            manualQuizTitle,
            manualQuizPrompt,
            manualAssignmentTitle,
            manualAssignmentBrief,
        ].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func loadLessonVideoRenderJobs() async {
        guard LessonVideoGenerationSettings.isLessonVideoJobHistoryEnabled,
              let url = LessonVideoGenerationSettings.remoteLessonVideoJobHistoryGETURL,
              let secret = LessonVideoGenerationSettings.lessonVideoJobListSecret
        else {
            lessonVideoRenderJobs = []
            lessonVideoJobsLoadError = nil
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let apiKey = LessonVideoGenerationSettings.remoteTextToVideoSupabaseAnonKey
        let bearer = LessonVideoGenerationSettings.remoteTextToVideoBearerToken ?? apiKey
        if let bearer, !bearer.isEmpty {
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }
        if let apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "apikey")
        }
        request.setValue(secret, forHTTPHeaderField: "x-wcs-job-list-secret")
        for (name, value) in LessonVideoGenerationSettings.remoteTextToVideoExtraHTTPHeaders {
            request.setValue(value, forHTTPHeaderField: name)
        }

        let session = LessonVideoGenerationSettings.makeURLSessionForTextToVideo()
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                lessonVideoJobsLoadError = "Invalid response."
                return
            }
            guard (200...299).contains(http.statusCode) else {
                lessonVideoJobsLoadError = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
                lessonVideoRenderJobs = []
                return
            }
            let decoded = try JSONDecoder().decode(LessonVideoRenderJobListResponse.self, from: data)
            lessonVideoRenderJobs = decoded.jobs
            lessonVideoJobsLoadError = nil
        } catch {
            lessonVideoRenderJobs = []
            lessonVideoJobsLoadError = error.localizedDescription
        }
    }

    func refreshVideoStatuses() async {
        var updated: [UUID: DraftVideoStatus] = [:]
        var assetsUpdated: [UUID: [GeneratedVideoAsset]] = [:]
        for draft in drafts {
            let status = await MockLearningStore.shared.videoGenerationStatus(for: draft)
            let assets = await MockLearningStore.shared.generatedVideoAssets(for: draft)
            updated[draft.id] = DraftVideoStatus(
                totalVideoLessons: status.totalVideoLessons,
                generatedVideoLessons: status.generatedVideoLessons,
                isGenerating: status.isGenerating,
                latestGeneratedAt: status.latestGeneratedAt
            )
            assetsUpdated[draft.id] = assets
        }
        videoStatusByDraftID = updated
        generatedAssetsByDraftID = assetsUpdated
    }

    /// Keeps admin cards live while AI module video generation is in flight.
    func startRealtimeVideoPolling() async {
        while !Task.isCancelled {
            await refreshVideoStatuses()
            let hasActiveGeneration = videoStatusByDraftID.values.contains { $0.isGenerating }
            let sleepNanos: UInt64 = hasActiveGeneration ? 2_000_000_000 : 5_000_000_000
            try? await Task.sleep(nanoseconds: sleepNanos)
        }
    }

    private func buildKajabiStylePrompt() -> String {
        let name = productName.isEmpty ? "Untitled Signature Program" : productName
        let learner = idealLearner.isEmpty ? "ambitious learners seeking measurable outcomes" : idealLearner
        let result = transformation.isEmpty ? "clear progression, implementation, and certification outcomes" : transformation
        let offer = offerStack.isEmpty ? "core modules, quizzes, assignments, certificate, and promotional assets" : offerStack
        let launch = launchAngle.isEmpty ? "high-converting launch with clear CTA and value proposition" : launchAngle
        let cohortSize = Int(preferredCohortSize.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 30
        let notes = prompt.isEmpty ? "No extra notes." : prompt

        return """
        Build a WCS AI Course Generation blueprint using a retrieval-plan-generate workflow.
        Product name: \(name)
        Ideal learner: \(learner)
        Transformation promise: \(result)
        Offer stack: \(offer)
        Launch angle: \(launch)
        Cohort preference: \(selectedCohortType.label)
        Preferred cohort size: \(cohortSize)
        Additional curriculum and brand notes: \(notes)

        Decompose the request into sub-queries, retrieve and rerank open-source evidence, map claims to citations, and deliver a structured program with modules, video lessons, reading materials, quizzes, assignments, Oxford-style grading guidance, certification criteria, and launch-ready promo copy.
        """
    }

    private func clearManualBackupInputs() {
        manualCourseTitle = ""
        manualSummary = ""
        manualModuleTitle = ""
        manualVideoTitle = ""
        manualVideoURL = ""
        manualReadingTitle = ""
        manualReadingMaterial = ""
        manualQuizTitle = ""
        manualQuizPrompt = ""
        manualAssignmentTitle = ""
        manualAssignmentBrief = ""
    }

    private func firstVideoLesson(in draft: AdminCourseDraft) -> (AdminModuleDraft, AdminLessonDraft)? {
        for module in draft.modules {
            if let lesson = module.lessons.first(where: { $0.kind == .video || $0.kind == .live }) {
                return (module, lesson)
            }
        }
        return nil
    }

    func updateImageSequenceSettings(for draftID: UUID, settings: ImageSequenceRenderSettings) {
        imageSequenceSettingsByDraftID[draftID] = settings
    }

    private func loadSavedConfiguration() {
        guard let data = UserDefaults.standard.data(forKey: Self.creatorDefaultsKey) else { return }
        let decoder = JSONDecoder()
        guard let saved = try? decoder.decode(CreatorDefaults.self, from: data) else { return }
        selectedAccessTier = saved.selectedAccessTier
        productName = saved.productName
        idealLearner = saved.idealLearner
        transformation = saved.transformation
        offerStack = saved.offerStack
        launchAngle = saved.launchAngle
        selectedCohortType = saved.selectedCohortType
        preferredCohortSize = saved.preferredCohortSize
        prompt = saved.prompt
        manualCourseTitle = saved.manualCourseTitle
        manualSummary = saved.manualSummary
        manualModuleTitle = saved.manualModuleTitle
        manualVideoTitle = saved.manualVideoTitle
        manualVideoURL = saved.manualVideoURL
        manualReadingTitle = saved.manualReadingTitle
        manualReadingMaterial = saved.manualReadingMaterial
        manualQuizTitle = saved.manualQuizTitle
        manualQuizPrompt = saved.manualQuizPrompt
        manualAssignmentTitle = saved.manualAssignmentTitle
        manualAssignmentBrief = saved.manualAssignmentBrief
    }
}

enum KajabiBlueprintTemplate: String, CaseIterable, Identifiable {
    case creatorEconomy = "Creator Economy Accelerator"
    case aiBusiness = "AI Business Operator"
    case leadership = "Executive Leadership Sprint"

    var id: String { rawValue }

    var defaultProductName: String {
        switch self {
        case .creatorEconomy: return "Creator Economy Accelerator"
        case .aiBusiness: return "AI Business Operator"
        case .leadership: return "Executive Leadership Sprint"
        }
    }

    var defaultLearner: String {
        switch self {
        case .creatorEconomy: return "creators and educators building digital products"
        case .aiBusiness: return "operators implementing AI systems in SMEs"
        case .leadership: return "mid-to-senior leaders improving strategic decision making"
        }
    }

    var defaultTransformation: String {
        switch self {
        case .creatorEconomy: return "go from idea to monetized course offer with repeatable launch process"
        case .aiBusiness: return "deploy practical AI workflows and governance in 8 weeks"
        case .leadership: return "lead teams with data-informed, high-trust execution"
        }
    }

    var defaultOffer: String {
        "weekly modules, office hours, quizzes, implementation assignments, certificate, and bonus templates"
    }

    var defaultLaunch: String {
        "premium yet accessible positioning, strong social proof, and conversion-first webinar funnel"
    }

    var defaultProductionNotes: String {
        "Prioritize concise lesson videos, downloadable worksheets, and learner accountability checkpoints."
    }
}
