//
//  AdminCourseCreatorViewModel.swift
//  WCS-Platform
//

import Combine
import Foundation

@MainActor
final class AdminCourseCreatorViewModel: ObservableObject {
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
    @Published var isGenerating = false
    @Published var drafts: [AdminCourseDraft] = []
    @Published var videoStatusByDraftID: [UUID: DraftVideoStatus] = [:]
    @Published var generatedAssetsByDraftID: [UUID: [GeneratedVideoAsset]] = [:]
    @Published var errorMessage: String?

    func unlock() {
        guard !accessCodeInput.isEmpty else {
            errorMessage = "Enter admin access code."
            return
        }
        if accessCodeInput == AppEnvironment.adminAccessCode {
            isUnlocked = true
            errorMessage = nil
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
            let finalPrompt = buildKajabiStylePrompt()
            _ = try await AdminCourseDraftStore.shared.generate(
                prompt: finalPrompt,
                createdBy: createdBy,
                accessTier: selectedAccessTier
            )
            prompt = ""
            drafts = await AdminCourseDraftStore.shared.allDrafts()
            await refreshVideoStatuses()
        } catch {
            errorMessage = error.localizedDescription
        }
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
    }

    func applyTemplate(_ template: KajabiBlueprintTemplate) {
        productName = template.defaultProductName
        idealLearner = template.defaultLearner
        transformation = template.defaultTransformation
        offerStack = template.defaultOffer
        launchAngle = template.defaultLaunch
        prompt = template.defaultProductionNotes
    }

    var canGenerate: Bool {
        buildKajabiStylePrompt().trimmingCharacters(in: .whitespacesAndNewlines).count >= 20
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
