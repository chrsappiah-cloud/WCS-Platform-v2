//
//  MockLearningStore.swift
//  WCS-Platform
//

import Foundation

struct CourseVideoGenerationStatus: Hashable {
    let totalVideoLessons: Int
    let generatedVideoLessons: Int
    let isGenerating: Bool
    let latestGeneratedAt: Date?
}

/// In-memory enrollments, lesson completion, and assignment submissions for mock mode so catalog, detail, and profile stay in sync.
actor MockLearningStore {
    static let shared = MockLearningStore()

    private let userId = UUID(uuidString: "F0000000-0000-0000-0000-000000000001")!
    private var enrollmentDates: [UUID: Date] = [:]
    private var enrollmentIds: [UUID: UUID] = [:]
    private var completedLessonIds: Set<UUID> = []
    private var submittedAssignments: [UUID: Submission] = [:]
    private var publishedCourses: [Course] = []
    private let videoGenerator = MockAIVideoGenerator()
    private var activeVideoGenerationCourseIDs: Set<UUID> = []

    private var enrolledCourseIds: Set<UUID> {
        Set(enrollmentDates.keys)
    }

    private let blockedAICourseTitleTerms = [
        "beginner",
        "beginners",
        "novice"
    ]

    private func notifyChange() {
        Task { @MainActor in
            NotificationCenter.default.post(name: .wcsLearningStateDidChange, object: nil)
        }
    }

    func snapshotCourses(forPremiumUser isPremium: Bool) -> [Course] {
        purgeBlockedAICourses()
        let allCourses = MockCourseCatalog.courses + publishedCourses
        return allCourses
            .filter { course in
                // Paid subscription programs should only be visible to premium users.
                !(course.price != nil && !isPremium)
            }
            .map { hydrate($0) }
    }

    func snapshotCourse(_ id: UUID) -> Course? {
        let allCourses = MockCourseCatalog.courses + publishedCourses
        guard let base = allCourses.first(where: { $0.id == id }) else { return nil }
        return hydrate(base)
    }

    func publishDraftToCatalog(_ draft: AdminCourseDraft) async {
        guard !isBlockedAICourseTitle(draft.title) else {
            // Explicitly drop disallowed beginner/novice AI courses.
            purgeBlockedAICourses()
            notifyChange()
            return
        }
        let cachedAssets = await videoGenerator.cachedVideoAssets(for: draft)
        let course = makeCourse(from: draft, generatedVideoAssets: cachedAssets, isVideoGenerationInFlight: true)
        if let index = publishedCourses.firstIndex(where: { $0.id == course.id }) {
            publishedCourses[index] = course
        } else {
            publishedCourses.insert(course, at: 0)
        }
        notifyChange()
        scheduleVideoGenerationIfNeeded(for: draft)
    }

    func deleteBlockedAICourses() {
        purgeBlockedAICourses()
        notifyChange()
    }

    func videoGenerationStatus(for draft: AdminCourseDraft) async -> CourseVideoGenerationStatus {
        let videoLessonIDs = Set(
            draft.modules
                .flatMap(\.lessons)
                .filter { $0.kind == .video || $0.kind == .live }
                .map(\.id)
        )
        let cachedAssets = await videoGenerator.cachedVideoAssets(for: draft)
        let matchedAssets = cachedAssets.values.filter { videoLessonIDs.contains($0.lessonId) }
        let generatedCount = matchedAssets.count
        let latestGeneratedAt = matchedAssets.map(\.generatedAt).max()
        return CourseVideoGenerationStatus(
            totalVideoLessons: videoLessonIDs.count,
            generatedVideoLessons: generatedCount,
            isGenerating: activeVideoGenerationCourseIDs.contains(draft.id),
            latestGeneratedAt: latestGeneratedAt
        )
    }

    func generatedVideoAssets(for draft: AdminCourseDraft) async -> [GeneratedVideoAsset] {
        let videoLessonIDs = Set(
            draft.modules
                .flatMap(\.lessons)
                .filter { $0.kind == .video || $0.kind == .live }
                .map(\.id)
        )
        let cachedAssets = await videoGenerator.cachedVideoAssets(for: draft)
        return cachedAssets.values
            .filter { videoLessonIDs.contains($0.lessonId) }
            .sorted(by: { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending })
    }

    func regenerateVideoAssets(for draft: AdminCourseDraft, clearCache: Bool) async {
        if clearCache {
            await videoGenerator.clearCachedVideoAssets(for: draft.id)
        }
        if let index = publishedCourses.firstIndex(where: { $0.id == draft.id }) {
            let cachedAssets = await videoGenerator.cachedVideoAssets(for: draft)
            publishedCourses[index] = makeCourse(
                from: draft,
                generatedVideoAssets: cachedAssets,
                isVideoGenerationInFlight: true
            )
            notifyChange()
        }
        activeVideoGenerationCourseIDs.remove(draft.id)
        scheduleVideoGenerationIfNeeded(for: draft)
    }

    private func hydrate(_ base: Course) -> Course {
        CourseHydration.apply(
            base: base,
            enrolledCourseIds: enrolledCourseIds,
            completedLessonIds: completedLessonIds,
            submittedAssignments: submittedAssignments
        )
    }

    func enroll(_ courseId: UUID) -> Enrollment {
        if enrollmentDates[courseId] == nil {
            enrollmentDates[courseId] = Date()
            enrollmentIds[courseId] = UUID()
        }
        notifyChange()
        return makeEnrollment(courseId: courseId)
    }

    func markProgress(courseId: UUID, lessonId: UUID, complete: Bool) throws -> Enrollment {
        guard enrollmentDates[courseId] != nil else {
            throw WCSAPIError(underlying: URLError(.dataNotAllowed), statusCode: 403, body: nil)
        }
        if complete {
            completedLessonIds.insert(lessonId)
        } else {
            completedLessonIds.remove(lessonId)
        }
        notifyChange()
        return makeEnrollment(courseId: courseId)
    }

    func submitAssignment(_ assignmentId: UUID, content: String?, attachments: [URL]) -> Submission {
        let submission = Submission(
            id: UUID(),
            content: content,
            attachments: attachments,
            submittedAt: Date(),
            feedback: "Received. Your instructor will review this submission.",
            grade: nil
        )
        submittedAssignments[assignmentId] = submission
        notifyChange()
        return submission
    }

    func currentUser() -> User {
        let enrollments = enrolledCourseIds.sorted(by: { $0.uuidString < $1.uuidString }).map { makeEnrollment(courseId: $0) }
        let mockPremium = UserDefaults.standard.bool(forKey: "wcs.mockPremiumMode")
        let subscriptions: [Subscription] = mockPremium ? [
            Subscription(
                id: UUID(),
                planId: "premium-monthly",
                planName: "Premium Membership",
                status: .active,
                startDate: Date(),
                endDate: nil,
                price: 29.99
            )
        ] : []
        return User(
            id: userId,
            email: "learner@worldclassscholars.org",
            name: "WCS Learner",
            photoURL: nil,
            subscriptions: subscriptions,
            enrollments: enrollments
        )
    }

    private func makeEnrollment(courseId: UUID) -> Enrollment {
        Enrollment(
            id: enrollmentIds[courseId] ?? UUID(),
            courseId: courseId,
            userId: userId,
            startDate: enrollmentDates[courseId] ?? Date(),
            endDate: nil,
            status: .active,
            progressPercentage: progressFraction(for: courseId)
        )
    }

    private func progressFraction(for courseId: UUID) -> Double {
        let allCourses = MockCourseCatalog.courses + publishedCourses
        guard let base = allCourses.first(where: { $0.id == courseId }) else { return 0 }
        let hydrated = hydrate(base)
        return CourseHydration.progressFraction(for: hydrated)
    }

    private func makeCourse(
        from draft: AdminCourseDraft,
        generatedVideoAssets: [UUID: GeneratedVideoAsset],
        isVideoGenerationInFlight: Bool
    ) -> Course {
        let totalQuizCount = draft.modules.flatMap(\.lessons).filter { $0.kind == .quiz }.count
        let totalAssignmentCount = draft.modules.flatMap(\.lessons).filter { $0.kind == .assignment }.count
        let totalVideoCount = draft.modules.flatMap(\.lessons).filter { $0.kind == .video || $0.kind == .live }.count
        let conciseSummary = draft.summary
            .split(separator: ".")
            .first
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) + "." }
            ?? draft.summary
        let compactOutcomes = draft.outcomes
            .prefix(3)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: " | ")
        let courseBrief = [
            "Course design goals: \(conciseSummary)",
            "Module overview: \(draft.modules.count) modules, \(totalVideoCount) video lessons, \(totalQuizCount) quizzes, \(totalAssignmentCount) assignments.",
            "Learning outcomes: \(compactOutcomes)"
        ].joined(separator: "\n")
        let reportSnapshot = CourseReportSnapshot(
            designGoals: conciseSummary,
            moduleOverview: "\(draft.modules.count) modules, \(totalVideoCount) video lessons, \(totalQuizCount) quizzes, \(totalAssignmentCount) assignments.",
            learningOutcomes: Array(draft.outcomes.prefix(4)),
            cohortRecommendation: "\(draft.cohortSelection.cohortType.label) · recommended size \(draft.cohortSelection.recommendedSize)",
            findings: draft.reportFindings.map {
                CourseReportFinding(
                    id: $0.id,
                    title: $0.title,
                    detail: $0.detail,
                    confidence: $0.confidence
                )
            }
        )
        let modules: [Module] = draft.modules.enumerated().map { offset, module in
            Module(
                id: module.id,
                title: module.title,
                description: module.goals.joined(separator: " "),
                order: offset + 1,
                isAvailable: true,
                isUnlocked: true,
                lessons: module.lessons.map { lesson in
                    let videoAsset = generatedVideoAssets[lesson.id]
                    let subtitle = [lesson.notes, videoAsset?.productionNotes]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    let generationSubtitle = subtitle.isEmpty && lesson.kind == .video && isVideoGenerationInFlight
                        ? "Generating AI lesson video in real time. This recording will be archived for reuse."
                        : subtitle
                    let fallbackVideoURL = fallbackPlaybackURL(for: lesson.id)
                    let manualBackupVideoURL = manualVideoURL(from: lesson.notes)
                    return Lesson(
                        id: lesson.id,
                        title: lesson.title,
                        subtitle: generationSubtitle.isEmpty ? nil : generationSubtitle,
                        type: mapLessonKind(lesson.kind),
                        videoURL: lesson.kind == .video ? (videoAsset?.playbackURL ?? manualBackupVideoURL ?? fallbackVideoURL) : nil,
                        durationSeconds: max(1, lesson.durationMinutes) * 60,
                        isCompleted: false,
                        isAvailable: true,
                        isUnlocked: true,
                        reading: lesson.kind == .reading ? ReadingContent(markdown: lesson.notes) : nil,
                        quiz: lesson.kind == .quiz ? makeGeneratedQuiz(from: lesson, moduleTitle: module.title, courseTitle: draft.title) : nil,
                        assignment: lesson.kind == .assignment ? Assignment(
                            id: UUID(),
                            title: lesson.title,
                            description: lesson.notes,
                            dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
                            maxAttempts: 1,
                            isSubmitted: false,
                            submission: nil
                        ) : nil
                    )
                }
            )
        }

        return Course(
            id: draft.id,
            title: draft.title,
            subtitle: draft.summary,
            description: courseBrief,
            thumbnailURL: "https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=1200&q=80",
            coverURL: "https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?w=1600&q=80",
            durationSeconds: max(1, draft.durationWeeks) * 3600,
            price: draft.accessTier == .paidSubscription ? 59.99 : nil,
            isEnrolled: false,
            isOwned: false,
            isUnlockedBySubscription: draft.accessTier == .paidSubscription,
            rating: 4.7,
            reviewCount: 0,
            organizationName: "World Class Scholars",
            level: draft.level,
            effortDescription: "\(max(1, draft.durationWeeks)) weeks",
            spokenLanguages: ["English"],
            modules: modules,
            courseReport: reportSnapshot
        )
    }

    private func scheduleVideoGenerationIfNeeded(for draft: AdminCourseDraft) {
        guard !activeVideoGenerationCourseIDs.contains(draft.id) else { return }
        activeVideoGenerationCourseIDs.insert(draft.id)
        Task {
            let assets = await videoGenerator.generateVideoAssets(for: draft) { asset in
                Task {
                    await self.applyGeneratedVideoAsset(asset, courseID: draft.id)
                }
            }
            finalizeVideoGeneration(courseID: draft.id, assets: assets)
        }
    }

    private func applyGeneratedVideoAsset(_ asset: GeneratedVideoAsset, courseID: UUID) {
        guard let courseIndex = publishedCourses.firstIndex(where: { $0.id == courseID }) else { return }
        var course = publishedCourses[courseIndex]
        let updatedModules = course.modules.map { module in
            let updatedLessons = module.lessons.map { lesson in
                guard lesson.id == asset.lessonId && lesson.type == .video else { return lesson }
                let previousSubtitle = lesson.subtitle ?? ""
                let isGenerationMessage = previousSubtitle.contains("Generating AI lesson video in real time")
                let safePlaybackURL = (asset.uploadSafetyReport?.isUploadSafe ?? false) ? asset.playbackURL : ""
                let safeVideoURL = safePlaybackURL.isEmpty ? nil : safePlaybackURL
                let mergedSubtitle = isGenerationMessage || previousSubtitle.isEmpty
                    ? [asset.productionNotes, asset.uploadSafetyReport?.rationale]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    : [previousSubtitle, asset.productionNotes].joined(separator: " ")
                return Lesson(
                    id: lesson.id,
                    title: lesson.title,
                    subtitle: mergedSubtitle,
                    type: lesson.type,
                    videoURL: safeVideoURL,
                    durationSeconds: lesson.durationSeconds,
                    isCompleted: lesson.isCompleted,
                    isAvailable: lesson.isAvailable,
                    isUnlocked: lesson.isUnlocked,
                    reading: lesson.reading,
                    quiz: lesson.quiz,
                    assignment: lesson.assignment
                )
            }
            return Module(
                id: module.id,
                title: module.title,
                description: module.description,
                order: module.order,
                isAvailable: module.isAvailable,
                isUnlocked: module.isUnlocked,
                lessons: updatedLessons
            )
        }
        course = course.copy(modules: updatedModules)
        publishedCourses[courseIndex] = course
        notifyChange()
    }

    private func finalizeVideoGeneration(courseID: UUID, assets: [UUID: GeneratedVideoAsset]) {
        for asset in assets.values {
            applyGeneratedVideoAsset(asset, courseID: courseID)
        }
        activeVideoGenerationCourseIDs.remove(courseID)
        notifyChange()
    }

    private func makeGeneratedQuiz(from lesson: AdminLessonDraft, moduleTitle: String, courseTitle: String) -> Quiz {
        let q1 = Question(
            id: UUID(),
            text: "What is the primary objective of \(moduleTitle.lowercased()) in \(courseTitle)?",
            type: .multipleChoice,
            options: [
                QuestionOption(id: UUID(), text: "Applying concepts in practical contexts"),
                QuestionOption(id: UUID(), text: "Skipping assessment and feedback"),
                QuestionOption(id: UUID(), text: "Studying without measurable outcomes")
            ],
            correctOptionIndex: 0,
            explanation: "Each module is designed for practical, measurable learning outcomes."
        )
        let q2 = Question(
            id: UUID(),
            text: "Formative quizzes support continuous feedback and progression.",
            type: .trueFalse,
            options: [
                QuestionOption(id: UUID(), text: "True"),
                QuestionOption(id: UUID(), text: "False")
            ],
            correctOptionIndex: 0,
            explanation: "Frequent checks are used to drive mastery."
        )
        let q3 = Question(
            id: UUID(),
            text: "Which artifact best demonstrates mastery in this lesson?",
            type: .multipleChoice,
            options: [
                QuestionOption(id: UUID(), text: "A completed assignment aligned to rubric criteria"),
                QuestionOption(id: UUID(), text: "An empty submission"),
                QuestionOption(id: UUID(), text: "Skipping the module")
            ],
            correctOptionIndex: 0,
            explanation: "Mastery is evidenced through assessed outputs."
        )

        return Quiz(
            id: UUID(),
            title: "\(lesson.title) Quiz",
            description: "AI-generated quiz with automated marking and Oxford-grade classification.",
            maxAttempts: 3,
            timeLimitSeconds: 600,
            passingScore: 2,
            questions: [q1, q2, q3]
        )
    }

    private func mapLessonKind(_ kind: AdminLessonDraft.Kind) -> LessonType {
        switch kind {
        case .video, .live:
            return .video
        case .reading:
            return .reading
        case .quiz:
            return .quiz
        case .assignment:
            return .assignment
        }
    }

    private func fallbackPlaybackURL(for lessonID: UUID) -> String {
        let samples = [
            "https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            "https://storage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
            "https://storage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4",
            "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4"
        ]
        let hash = lessonID.uuidString.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return samples[hash % samples.count]
    }

    private func manualVideoURL(from notes: String) -> String? {
        guard let range = notes.range(of: "http") else { return nil }
        let candidate = String(notes[range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: candidate),
              ["http", "https"].contains((url.scheme ?? "").lowercased())
        else {
            return nil
        }
        return candidate
    }

    private func isBlockedAICourseTitle(_ title: String) -> Bool {
        let lower = title.lowercased()
        return blockedAICourseTitleTerms.contains(where: { lower.contains($0) })
    }

    private func purgeBlockedAICourses() {
        publishedCourses.removeAll { isBlockedAICourseTitle($0.title) }
    }
}
