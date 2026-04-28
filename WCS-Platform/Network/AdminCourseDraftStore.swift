//
//  AdminCourseDraftStore.swift
//  WCS-Platform
//

import Foundation

actor AdminCourseDraftStore {
    static let shared = AdminCourseDraftStore(generator: MockAICourseGenerator())

    private var drafts: [AdminCourseDraft] = []
    private let generator: AICourseGenerating
    private let blockedAICourseTitleTerms = [
        "beginner",
        "beginners",
        "novice"
    ]
    private let blockedPublishTerms = [
        "search question",
        "search query",
        "what is",
        "how to",
        "why does",
        "can i",
        "?"
    ]
    private let manualBackupReferenceMarker = "manual-backup-authoring"

    init(generator: AICourseGenerating) {
        self.generator = generator
    }

    private func notifyChange() {
        Task { @MainActor in
            NotificationCenter.default.post(name: .wcsAdminDraftsDidChange, object: nil)
        }
    }

    func allDrafts() -> [AdminCourseDraft] {
        purgeBlockedDrafts()
        return drafts.sorted(by: { $0.updatedAt > $1.updatedAt })
    }

    func generate(prompt: String, createdBy: String, accessTier: AdminCourseAccessTier) async throws -> AdminCourseDraft {
        let draft = try await generator.generateDraft(prompt: prompt, createdBy: createdBy, accessTier: accessTier)
        if isBlockedAICourseTitle(draft.title) {
            purgeBlockedDrafts()
            notifyChange()
            throw NSError(domain: "WCSAdminAI", code: 1001, userInfo: [
                NSLocalizedDescriptionKey: "This beginner/novice AI course is blocked and has been removed."
            ])
        }
        drafts.insert(draft, at: 0)
        notifyChange()
        return draft
    }

    func createManualBackupDraft(
        createdBy: String,
        accessTier: AdminCourseAccessTier,
        courseTitle: String,
        summary: String,
        moduleTitle: String,
        videoTitle: String,
        videoURL: String,
        readingTitle: String,
        readingMaterial: String,
        quizTitle: String,
        quizPrompt: String,
        assignmentTitle: String,
        assignmentBrief: String
    ) throws -> AdminCourseDraft {
        let cleanCourseTitle = courseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedVideoURL = videoURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let validatedVideoURL = LessonManualVideoBackup.validatedHTTPSURL(trimmedVideoURL) else {
            throw NSError(domain: "WCSAdminAI", code: 1105, userInfo: [
                NSLocalizedDescriptionKey: "Video URL must be a valid https:// playback link (MP4, HLS, or signed CDN URL).",
            ])
        }
        let module = AdminModuleDraft(
            id: UUID(),
            title: moduleTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            goals: [
                "Maintain continuity when AI generation is unavailable.",
                "Provide manually authored backups for all lesson types."
            ],
            lessons: [
                AdminLessonDraft(
                    id: UUID(),
                    title: videoTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    kind: .video,
                    durationMinutes: 20,
                    notes: LessonManualVideoBackup.mergeURLLine(
                        into: "",
                        url: validatedVideoURL
                    )
                ),
                AdminLessonDraft(
                    id: UUID(),
                    title: readingTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    kind: .reading,
                    durationMinutes: 15,
                    notes: readingMaterial.trimmingCharacters(in: .whitespacesAndNewlines)
                ),
                AdminLessonDraft(
                    id: UUID(),
                    title: quizTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    kind: .quiz,
                    durationMinutes: 10,
                    notes: quizPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                ),
                AdminLessonDraft(
                    id: UUID(),
                    title: assignmentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    kind: .assignment,
                    durationMinutes: 30,
                    notes: assignmentBrief.trimmingCharacters(in: .whitespacesAndNewlines)
                ),
            ]
        )
        let now = Date()
        let draft = AdminCourseDraft(
            id: UUID(),
            createdAt: now,
            updatedAt: now,
            createdBy: createdBy,
            title: cleanCourseTitle,
            summary: cleanSummary,
            targetAudience: "Learners requiring continuity access",
            level: "All levels",
            durationWeeks: 4,
            outcomes: [
                "Access module videos through manual backup links.",
                "Continue with reading, quiz, and assignment activities without AI generation.",
                "Preserve delivery continuity during automation interruptions."
            ],
            modules: [module],
            status: .readyForReview,
            accessTier: accessTier,
            sourceReferences: [
                manualBackupReferenceMarker,
                "Manual course backup package"
            ],
            promotionalCopy: [
                "Manual continuity track for uninterrupted learning."
            ],
            funnelPreview: AIFunnelPreview(
                headline: "\(cleanCourseTitle) - Manual Backup",
                subheadline: "Fallback delivery path for uninterrupted teaching and learning.",
                callToAction: "Start backup module",
                offerBullets: ["Video", "Reading", "Quiz", "Assignment"],
                emailHooks: ["Keep learners moving while automation recovers."]
            ),
            reasoningReport: AIReasoningReport(
                focusQuestion: "How do we keep delivery live when automation is offline?",
                assumptions: ["Manual authoring ensures continuity."],
                reasoningSteps: [
                    AIReasoningStep(
                        id: UUID(),
                        title: "Create complete manual lesson set",
                        analysis: "Added manual video, reading, quiz, and assignment lessons as backup path.",
                        evidence: ["Operational continuity requirement"]
                    )
                ],
                conclusion: "Manual backup content can be published immediately as a fallback.",
                confidenceScore: 0.9
            ),
            researchTrace: AIResearchTrace(
                engineName: "Manual Backup Authoring",
                retrievalMode: "Manual",
                generatedQueries: ["manual backup course delivery"],
                evidenceCards: [
                    AIEvidenceCard(
                        id: UUID(),
                        title: "Fallback delivery policy",
                        source: "Internal operations",
                        snippet: "Maintain student access during AI pipeline outages.",
                        relevanceScore: 0.95,
                        freshnessScore: 0.95
                    )
                ],
                qualityGate: AIQualityGate(
                    passed: true,
                    threshold: 0.7,
                    score: 0.95,
                    rationale: "Manual package includes all core lesson modalities."
                ),
                citationMap: [
                    AICitationMapping(
                        id: UUID(),
                        claim: "Backup content includes all critical learning assets.",
                        sourceTitle: "Fallback delivery policy",
                        sourceSystem: "Internal operations"
                    )
                ]
            ),
            cohortSelection: AICohortSelection(
                cohortType: .selfPaced,
                recommendedSize: 30,
                rationale: "Fallback path supports asynchronous continuity."
            ),
            reportFindings: [
                AICourseReportFinding(
                    id: UUID(),
                    title: "Continuity-ready backup",
                    detail: "Manual upload pathway can be published without automation services.",
                    confidence: 0.95
                )
            ]
        )
        drafts.insert(draft, at: 0)
        notifyChange()
        return draft
    }

    /// Persists a per-lesson HTTPS playback URL used when AI/BFF video is missing or unreliable (`MockLearningStore` prefers this URL).
    func setManualLessonVideoPlaybackURL(
        draftId: UUID,
        moduleId: UUID,
        lessonId: UUID,
        urlString: String
    ) async throws {
        guard let idx = drafts.firstIndex(where: { $0.id == draftId }) else {
            throw NSError(domain: "WCSAdminAI", code: 1100, userInfo: [
                NSLocalizedDescriptionKey: "Draft not found.",
            ])
        }
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, LessonManualVideoBackup.validatedHTTPSURL(trimmed) == nil {
            throw NSError(domain: "WCSAdminAI", code: 1101, userInfo: [
                NSLocalizedDescriptionKey: "Enter a valid https:// playback URL (MP4, HLS, or signed CDN).",
            ])
        }

        var draft = drafts[idx]
        guard let mIdx = draft.modules.firstIndex(where: { $0.id == moduleId }) else {
            throw NSError(domain: "WCSAdminAI", code: 1102, userInfo: [
                NSLocalizedDescriptionKey: "Module not found in this draft.",
            ])
        }
        guard let lIdx = draft.modules[mIdx].lessons.firstIndex(where: { $0.id == lessonId }) else {
            throw NSError(domain: "WCSAdminAI", code: 1103, userInfo: [
                NSLocalizedDescriptionKey: "Lesson not found in this module.",
            ])
        }
        let kind = draft.modules[mIdx].lessons[lIdx].kind
        guard kind == .video || kind == .live else {
            throw NSError(domain: "WCSAdminAI", code: 1104, userInfo: [
                NSLocalizedDescriptionKey: "Manual video backup applies to video or live lessons only.",
            ])
        }

        var lesson = draft.modules[mIdx].lessons[lIdx]
        if trimmed.isEmpty {
            lesson.notes = LessonManualVideoBackup.stripMachineLines(from: lesson.notes)
            await MockLearningStore.shared.clearManualLessonVideoBackup(lessonId: lessonId)
        } else {
            lesson.notes = LessonManualVideoBackup.mergeURLLine(into: lesson.notes, url: trimmed)
            await MockLearningStore.shared.recordManualLessonVideoBackup(lessonId: lessonId, url: trimmed)
        }
        draft.modules[mIdx].lessons[lIdx] = lesson
        draft.updatedAt = Date()
        drafts[idx] = draft
        await MockLearningStore.shared.rebuildPublishedCourseIfPresent(draft: draft)
        notifyChange()
    }

    func markPublished(_ id: UUID) async throws {
        guard let idx = drafts.firstIndex(where: { $0.id == id }) else { return }
        guard isPublishableGeneratedOutput(drafts[idx]) else {
            throw NSError(domain: "WCSAdminAI", code: 1002, userInfo: [
                NSLocalizedDescriptionKey: "Publish blocked: only structured AI-generated course outputs can be published. Remove search/question-style inputs and regenerate."
            ])
        }

        let actor = await MockLearningStore.shared.currentUser()
        let canPublish = actor.role == .orgAdmin || actor.role == .admin
        guard canPublish else {
            throw NSError(domain: "WCSAdminAI", code: 1004, userInfo: [
                NSLocalizedDescriptionKey: "Publishing is restricted to administrators."
            ])
        }
        drafts[idx].status = .published
        drafts[idx].updatedAt = Date()
        await MockLearningStore.shared.publishDraftToCatalog(drafts[idx])
        let publishedDraftId = drafts[idx].id.uuidString
        let publishedModuleCount = "\(drafts[idx].modules.count)"
        let publishedLessonCount = "\(drafts[idx].modules.flatMap(\.lessons).count)"
        await MainActor.run {
            Telemetry.event(
                "contentops.publish.synced_learning_graph",
                attributes: [
                    "draftId": publishedDraftId,
                    "moduleCount": publishedModuleCount,
                    "lessonCount": publishedLessonCount,
                ]
            )
        }
        notifyChange()
    }

    func clearAll() {
        drafts.removeAll()
        notifyChange()
    }

    func deleteBlockedDraftsAndCourses() async {
        purgeBlockedDrafts()
        await MockLearningStore.shared.deleteBlockedAICourses()
        notifyChange()
    }

    private func isBlockedAICourseTitle(_ title: String) -> Bool {
        let lower = title.lowercased()
        return blockedAICourseTitleTerms.contains(where: { lower.contains($0) })
    }

    private func purgeBlockedDrafts() {
        drafts.removeAll { isBlockedAICourseTitle($0.title) }
    }

    private func isPublishableGeneratedOutput(_ draft: AdminCourseDraft) -> Bool {
        guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard !draft.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard !draft.modules.isEmpty else { return false }
        guard draft.modules.allSatisfy({ !$0.lessons.isEmpty }) else { return false }

        let normalized = "\(draft.title) \(draft.summary)".lowercased()
        if blockedPublishTerms.contains(where: { normalized.contains($0) }) {
            return false
        }

        // Must contain evidence of generated course structure, not raw retrieval prompts.
        let hasCourseSignals = !draft.outcomes.isEmpty &&
            draft.reasoningReport != nil &&
            draft.researchTrace != nil &&
            !draft.reportFindings.isEmpty
        let isManualBackupDraft = draft.sourceReferences.contains(manualBackupReferenceMarker)
        if isManualBackupDraft {
            return !draft.outcomes.isEmpty
        }
        return hasCourseSignals
    }
}
