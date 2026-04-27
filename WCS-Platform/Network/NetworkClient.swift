//
//  NetworkClient.swift
//  WCS-Platform
//

import Foundation

/// REST shell with a mock path for local UI development. Point `AppEnvironment.platformAPIBaseURL` at your WCS API when ready.
nonisolated final class NetworkClient: IdentityService, CatalogService, LearningService, CommunityService, CommerceService, ContentOpsService {
    static let shared = NetworkClient()

    /// When `true`, catalog and mutations resolve locally without network I/O.
    var useMocks: Bool = true

    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder

    private init(session: URLSession = .shared) {
        self.session = session
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.dateEncodingStrategy = .iso8601
    }

    private func loadToken() -> String {
        UserDefaults.standard.string(forKey: "wcs.authToken") ?? ""
    }

    private func persistToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: "wcs.authToken")
    }

    private func broadcastLearningChange() {
        Task { @MainActor in
            NotificationCenter.default.post(name: .wcsLearningStateDidChange, object: nil)
        }
    }

    private func rawRequest<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> T {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let baseString = AppEnvironment.platformAPIBaseURL.absoluteString
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urlString = trimmed.isEmpty ? baseString : "\(baseString)/\(trimmed)"
        guard let url = URL(string: urlString) else {
            throw WCSAPIError(underlying: URLError(.badURL), statusCode: nil, body: nil)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let token = loadToken()
        if !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw WCSAPIError(underlying: URLError(.badServerResponse), statusCode: nil, body: data)
        }
        if !(200 ..< 300).contains(http.statusCode) {
            throw WCSAPIError(underlying: HTTPStatusError(status: http.statusCode), statusCode: http.statusCode, body: data)
        }
        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            throw WCSAPIError(underlying: error, statusCode: http.statusCode, body: data)
        }
    }

    private func resolveIdentitySnapshot() async throws -> WCSIdentitySnapshot {
        try await WCSPlatformAccessPolicy.identitySnapshot(useMocks: useMocks) {
            try await self.rawRequest("users/me", method: "GET")
        }
    }

    private func rawFetchCourse(_ courseId: UUID) async throws -> Course {
        if useMocks {
            try await Task.sleep(nanoseconds: 120_000_000)
            guard let course = await MockLearningStore.shared.snapshotCourse(courseId) else {
                throw WCSAPIError(underlying: URLError(.fileDoesNotExist), statusCode: 404, body: nil)
            }
            return course
        }
        return try await rawRequest("courses/\(courseId.uuidString)", method: "GET")
    }

    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> T {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let baseString = AppEnvironment.platformAPIBaseURL.absoluteString
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urlString = trimmed.isEmpty ? baseString : "\(baseString)/\(trimmed)"
        guard let url = URL(string: urlString) else {
            throw WCSAPIError(underlying: URLError(.badURL), statusCode: nil, body: nil)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let token = loadToken()
        if !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw WCSAPIError(underlying: URLError(.badServerResponse), statusCode: nil, body: data)
        }
        if !(200 ..< 300).contains(http.statusCode) {
            throw WCSAPIError(underlying: HTTPStatusError(status: http.statusCode), statusCode: http.statusCode, body: data)
        }
        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            throw WCSAPIError(underlying: error, statusCode: http.statusCode, body: data)
        }
    }

    func currentUser() async throws -> User {
        if useMocks {
            return await MockLearningStore.shared.currentUser()
        }
        return try await rawRequest("users/me", method: "GET")
    }

    func signUp(email: String, password: String, displayName: String) async throws -> User {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty, !password.isEmpty else {
            throw WCSAPIError(underlying: URLError(.userAuthenticationRequired), statusCode: 400, body: nil)
        }
        if useMocks {
            // Mock auth session; backend will own this in live mode.
            persistToken("mock-token-\(UUID().uuidString)")
            var user = await MockLearningStore.shared.currentUser()
            user = User(
                id: user.id,
                email: normalizedEmail,
                name: displayName.isEmpty ? user.name : displayName,
                photoURL: user.photoURL,
                role: user.role,
                activeOrganizationId: user.activeOrganizationId,
                memberships: user.memberships,
                subscriptions: user.subscriptions,
                enrollments: user.enrollments
            )
            return user
        }
        struct SignupRequest: Codable {
            let email: String
            let password: String
            let displayName: String
        }
        let encoded = try jsonEncoder.encode(SignupRequest(email: normalizedEmail, password: password, displayName: displayName))
        return try await rawRequest("auth/signup", method: "POST", body: encoded)
    }

    func logIn(email: String, password: String) async throws -> User {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty, !password.isEmpty else {
            throw WCSAPIError(underlying: URLError(.userAuthenticationRequired), statusCode: 400, body: nil)
        }
        if useMocks {
            persistToken("mock-token-\(UUID().uuidString)")
            return await MockLearningStore.shared.currentUser()
        }
        struct LoginRequest: Codable {
            let email: String
            let password: String
        }
        struct LoginResponse: Decodable {
            let token: String
            let user: User
        }
        let encoded = try jsonEncoder.encode(LoginRequest(email: normalizedEmail, password: password))
        let response: LoginResponse = try await rawRequest("auth/login", method: "POST", body: encoded)
        persistToken(response.token)
        return response.user
    }

    func switchOrganization(_ organizationId: UUID) async throws -> User {
        if useMocks {
            var user = await MockLearningStore.shared.currentUser()
            user.activeOrganizationId = organizationId
            return user
        }
        struct SwitchOrganizationRequest: Codable {
            let organizationId: UUID
        }
        let encoded = try jsonEncoder.encode(SwitchOrganizationRequest(organizationId: organizationId))
        return try await rawRequest("identity/switch-organization", method: "POST", body: encoded)
    }

    func fetchAvailableCourses() async throws -> [Course] {
        let snapshot = try await resolveIdentitySnapshot()
        try await WCSPlatformAccessPolicy.assertAllowed(
            snapshot: snapshot,
            operation: .catalogBrowse,
            courseProvider: { id in try await self.rawFetchCourse(id) }
        )

        if useMocks {
            try await Task.sleep(nanoseconds: 180_000_000)
            let user = await MockLearningStore.shared.currentUser()
            let courses = await MockLearningStore.shared.snapshotCourses(forPremiumUser: user.isPremium)
            return courses.map { WCSPlatformAccessPolicy.redactCourseForCatalogIfNeeded(snapshot: snapshot, course: $0) }
        }
        let response: CourseListResponse = try await request("courses/available", method: "GET")
        return response.courses.map { WCSPlatformAccessPolicy.redactCourseForCatalogIfNeeded(snapshot: snapshot, course: $0) }
    }

    func discoverPrograms() async throws -> [Course] {
        try await fetchAvailableCourses()
    }

    func loadProgram(_ id: UUID) async throws -> Course {
        try await fetchCourse(id)
    }

    func fetchDiscoverPayload() async throws -> DiscoverPayload {
        let user = try await currentUser()
        let identity = WCSDomainProjector.identity(from: user)
        let courses = try await fetchAvailableCourses()

        let cards: [DiscoverProgramCard] = courses.enumerated().map { index, course in
            let tags = [course.level ?? "general", course.organizationName ?? "wcs"]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            let featuredPlacement = index < 6 ? index + 1 : nil
            let catalog = WCSDomainProjector.catalog(from: course, tags: tags, featuredPlacement: featuredPlacement)
            let enrollment = user.enrollments.first(where: { $0.courseId == course.id })
            let learning = WCSDomainProjector.learning(from: course, enrollment: enrollment)
            let commerce = WCSDomainProjector.commerce(from: course, user: user)
            return DiscoverProgramCard(id: course.id, course: course, catalog: catalog, learning: learning, commerce: commerce)
        }

        let featured = cards.filter { $0.catalog.featuredPlacement != nil }
            .sorted { ($0.catalog.featuredPlacement ?? .max) < ($1.catalog.featuredPlacement ?? .max) }
        let profile = WCSDomainProjector.profile(from: user)
        let analytics = WCSDomainProjector.analytics(from: Telemetry.recentEvents(limit: 120))

        return DiscoverPayload(
            identity: identity,
            featuredPrograms: featured,
            allPrograms: cards,
            profile: profile,
            analytics: analytics,
            generatedAt: Date()
        )
    }

    func fetchCourse(_ courseId: UUID) async throws -> Course {
        let snapshot = try await resolveIdentitySnapshot()
        try await WCSPlatformAccessPolicy.assertAllowed(
            snapshot: snapshot,
            operation: .catalogCourseDetail(courseId: courseId),
            courseProvider: { id in try await self.rawFetchCourse(id) }
        )

        let loaded = try await rawFetchCourse(courseId)
        return WCSPlatformAccessPolicy.redactCourseForCatalogIfNeeded(snapshot: snapshot, course: loaded)
    }

    func enrollInCourse(_ courseId: UUID) async throws -> Enrollment {
        let snapshot = try await resolveIdentitySnapshot()
        let course = try await rawFetchCourse(courseId)
        try await WCSPlatformAccessPolicy.assertAllowed(
            snapshot: snapshot,
            operation: .commerceEnroll(courseId: courseId),
            courseProvider: { _ in course }
        )

        if useMocks {
            try await Task.sleep(nanoseconds: 160_000_000)
            return await MockLearningStore.shared.enroll(courseId)
        }
        let encoded = try jsonEncoder.encode(EnrollmentCreateRequest(courseId: courseId))
        let result: Enrollment = try await request("enrollments", method: "POST", body: encoded)
        broadcastLearningChange()
        return result
    }

    func enroll(programId: UUID) async throws -> Enrollment {
        try await enrollInCourse(programId)
    }

    func markProgress(programId: UUID, moduleId: UUID, lessonId: UUID, complete: Bool) async throws -> Enrollment {
        try await updateLessonProgress(courseId: programId, moduleId: moduleId, lessonId: lessonId, complete: complete)
    }

    func updateLessonProgress(
        courseId: UUID,
        moduleId: UUID,
        lessonId: UUID,
        complete: Bool
    ) async throws -> Enrollment {
        let snapshot = try await resolveIdentitySnapshot()
        try await WCSPlatformAccessPolicy.assertAllowed(
            snapshot: snapshot,
            operation: .learningProgress(courseId: courseId, moduleId: moduleId, lessonId: lessonId),
            courseProvider: { id in try await self.rawFetchCourse(id) }
        )

        if useMocks {
            try await Task.sleep(nanoseconds: 120_000_000)
            return try await MockLearningStore.shared.markProgress(courseId: courseId, lessonId: lessonId, complete: complete)
        }
        let payload = LessonProgressRequest(
            courseId: courseId,
            moduleId: moduleId,
            lessonId: lessonId,
            complete: complete
        )
        let encoded = try jsonEncoder.encode(payload)
        let result: Enrollment = try await request("enrollments/\(courseId.uuidString)/progress", method: "POST", body: encoded)
        broadcastLearningChange()
        return result
    }

    func submitQuiz(
        _ quizId: UUID,
        answers: [UUID: Int],
        courseId: UUID?,
        moduleId: UUID?,
        lessonId: UUID?
    ) async throws -> QuizSubmissionResult {
        if useMocks {
            let snapshot = try await resolveIdentitySnapshot()
            if let courseId, let moduleId, let lessonId {
                try await WCSPlatformAccessPolicy.assertAllowed(
                    snapshot: snapshot,
                    operation: .learningQuizSubmit(courseId: courseId, moduleId: moduleId, lessonId: lessonId, quizId: quizId),
                    courseProvider: { id in try await self.rawFetchCourse(id) }
                )
            } else if let resolved = MockCourseCatalog.findQuizLocation(id: quizId) {
                try await WCSPlatformAccessPolicy.assertAllowed(
                    snapshot: snapshot,
                    operation: .learningQuizSubmit(
                        courseId: resolved.courseId,
                        moduleId: resolved.moduleId,
                        lessonId: resolved.lessonId,
                        quizId: quizId
                    ),
                    courseProvider: { id in try await self.rawFetchCourse(id) }
                )
            } else {
                throw WCSAPIError(underlying: URLError(.dataNotAllowed), statusCode: 403, body: nil)
            }

            try await Task.sleep(nanoseconds: 160_000_000)
            guard let quiz = MockCourseCatalog.findQuiz(id: quizId) else {
                throw WCSAPIError(underlying: URLError(.fileDoesNotExist), statusCode: 404, body: nil)
            }
            var score = 0
            for q in quiz.questions {
                if let picked = answers[q.id], picked == q.correctOptionIndex {
                    score += 1
                }
            }
            let total = quiz.questions.count
            let percentage = total > 0 ? (Double(score) / Double(total)) * 100 : 0
            let grade = OxfordGrading.grade(for: percentage)
            let passed = score >= quiz.passingScore
            let certificate = passed ? CourseCertificate(
                id: UUID(),
                learnerName: "WCS Learner",
                courseTitle: quiz.title,
                grade: grade,
                awardedAt: Date(),
                verificationCode: String(UUID().uuidString.prefix(8)).uppercased()
            ) : nil
            let result = QuizSubmissionResult(
                score: score,
                total: total,
                percentage: percentage,
                oxfordGrade: grade,
                isPassed: passed,
                passedAt: passed ? Date() : nil,
                feedback: passed ? "Great work. You are eligible for certification." : "Review the explanations and try again.",
                certification: certificate
            )

            if let certificate {
                Telemetry.event(
                    "profile.milestone.certificate_earned",
                    identity: snapshot,
                    attributes: [
                        "quizId": quizId.uuidString,
                        "verification": certificate.verificationCode,
                    ]
                )
            }

            return result
        }

        let snapshot = try await resolveIdentitySnapshot()
        guard let courseId, let moduleId, let lessonId else {
            throw WCSAPIError(underlying: URLError(.dataNotAllowed), statusCode: 403, body: nil)
        }
        try await WCSPlatformAccessPolicy.assertAllowed(
            snapshot: snapshot,
            operation: .learningQuizSubmit(courseId: courseId, moduleId: moduleId, lessonId: lessonId, quizId: quizId),
            courseProvider: { id in try await self.rawFetchCourse(id) }
        )

        let encoded = try jsonEncoder.encode(QuizSubmissionRequest(quizId: quizId, answers: answers))
        return try await request("quizzes/\(quizId.uuidString)/submit", method: "POST", body: encoded)
    }

    func submitAssignment(
        _ assignmentId: UUID,
        content: String?,
        attachments: [URL],
        courseId: UUID,
        moduleId: UUID,
        lessonId: UUID
    ) async throws -> Submission {
        let snapshot = try await resolveIdentitySnapshot()
        try await WCSPlatformAccessPolicy.assertAllowed(
            snapshot: snapshot,
            operation: .learningAssignmentSubmit(
                courseId: courseId,
                moduleId: moduleId,
                lessonId: lessonId,
                assignmentId: assignmentId
            ),
            courseProvider: { id in try await self.rawFetchCourse(id) }
        )

        if useMocks {
            try await Task.sleep(nanoseconds: 160_000_000)
            return await MockLearningStore.shared.submitAssignment(assignmentId, content: content, attachments: attachments)
        }
        let payload = AssignmentSubmissionRequest(
            assignmentId: assignmentId,
            content: content,
            attachments: attachments.map(\.absoluteString)
        )
        let encoded = try jsonEncoder.encode(payload)
        let result: Submission = try await request("assignments/\(assignmentId.uuidString)/submit", method: "POST", body: encoded)
        broadcastLearningChange()
        return result
    }

    func fetchDiscussionFeed(topicID: String?) async throws -> DiscussionFeedResponse {
        let snapshot = try await resolveIdentitySnapshot()
        try await WCSPlatformAccessPolicy.assertAllowed(
            snapshot: snapshot,
            operation: .communityFeed(topicID: topicID),
            courseProvider: { id in try await self.rawFetchCourse(id) }
        )

        if useMocks {
            try await Task.sleep(nanoseconds: 120_000_000)
            return await MockDiscussionStore.shared.feed(topicID: topicID)
        }
        let query = topicID.map { "?topic=\($0)" } ?? ""
        return try await request("discussion/feed\(query)", method: "GET")
    }

    func createDiscussionPost(topicID: String, body: String, authorName: String) async throws -> DiscussionPost {
        let snapshot = try await resolveIdentitySnapshot()
        try await WCSPlatformAccessPolicy.assertAllowed(
            snapshot: snapshot,
            operation: .communityPost(topicID: topicID),
            courseProvider: { id in try await self.rawFetchCourse(id) }
        )

        if useMocks {
            try await Task.sleep(nanoseconds: 100_000_000)
            return await MockDiscussionStore.shared.createPost(topicID: topicID, body: body, authorName: authorName)
        }
        let encoded = try jsonEncoder.encode(DiscussionCreateRequest(topicID: topicID, body: body))
        return try await request("discussion/posts", method: "POST", body: encoded)
    }

    func loadDiscussion(topicID: String?) async throws -> DiscussionFeedResponse {
        try await fetchDiscussionFeed(topicID: topicID)
    }

    func postDiscussion(topicID: String, body: String, authorName: String) async throws -> DiscussionPost {
        try await createDiscussionPost(topicID: topicID, body: body, authorName: authorName)
    }

    func canAccessProgram(_ course: Course, user: User) -> Bool {
        if user.isAdmin { return true }
        if course.isOwned || course.isEnrolled { return true }
        if course.isUnlockedBySubscription { return user.isPremium }
        if course.price == nil { return true }
        return user.isPremium
    }

    func fetchSubscriptionPlans() async throws -> [WCSSubscriptionPlan] {
        let snapshot = try await resolveIdentitySnapshot()
        try await WCSPlatformAccessPolicy.assertAllowed(
            snapshot: snapshot,
            operation: .commercePlansRead,
            courseProvider: { id in try await self.rawFetchCourse(id) }
        )

        if useMocks {
            return [
                WCSSubscriptionPlan(
                    id: "free-audit",
                    displayName: "Free Audit",
                    segment: .individual,
                    isFreeTier: true,
                    monthlyPriceUSD: 0,
                    description: "Audit selected lessons and community discussions.",
                    appleProductID: nil
                ),
                WCSSubscriptionPlan(
                    id: "individual-pro",
                    displayName: "Individual Pro",
                    segment: .individual,
                    isFreeTier: false,
                    monthlyPriceUSD: 29.99,
                    description: "Full course access, assessments, and certificates.",
                    appleProductID: AppEnvironment.appleSubscriptionProductIDs.first
                ),
                WCSSubscriptionPlan(
                    id: "enterprise-seat",
                    displayName: "Enterprise Seats",
                    segment: .enterprise,
                    isFreeTier: false,
                    monthlyPriceUSD: 99,
                    description: "Managed cohorts, seat packs, and admin reporting.",
                    appleProductID: nil
                ),
                WCSSubscriptionPlan(
                    id: "investor-insight",
                    displayName: "Investor Insight Access",
                    segment: .investor,
                    isFreeTier: false,
                    monthlyPriceUSD: 499,
                    description: "Governance updates, KPI access, and diligence portal.",
                    appleProductID: nil
                ),
            ]
        }
        return try await rawRequest("/commerce/plans", method: "GET")
    }

    func fetchAdminFinanceSnapshot() async throws -> WCSAdminFinanceSnapshot {
        let snapshot = try await resolveIdentitySnapshot()
        try await WCSPlatformAccessPolicy.assertAllowed(
            snapshot: snapshot,
            operation: .commerceAdminFinanceRead,
            courseProvider: { id in try await self.rawFetchCourse(id) }
        )

        if useMocks {
            return WCSAdminFinanceSnapshot(
                asOf: Date(),
                grossRevenueUSD: 12840.55,
                feesUSD: 413.22,
                netRevenueUSD: 12427.33,
                activeLearnerSubscriptions: 312,
                activeEnterpriseContracts: 6,
                activeInvestorCommitments: 3,
                breakdown: WCSRevenueBreakdown(
                    individualUSD: 8420.10,
                    enterpriseUSD: 3160.45,
                    investorUSD: 1260.00
                ),
                payout: WCSPayoutStatus(
                    pendingUSD: 1750.40,
                    paidOutUSD: 10676.93,
                    bankAccountAlias: "WCS Operations Account •••• 2044",
                    lastSettlementAt: Date().addingTimeInterval(-60 * 60 * 24)
                )
            )
        }
        return try await rawRequest("/commerce/admin/finance/snapshot", method: "GET")
    }

    func publishDraft(_ id: UUID) async throws {
        try await AdminCourseDraftStore.shared.markPublished(id)
    }

    func fetchPipelineHealthStatus() async throws -> PipelineHealthStatus {
        let snapshot = try await resolveIdentitySnapshot()
        try await WCSPlatformAccessPolicy.assertAllowed(
            snapshot: snapshot,
            operation: .adminInfrastructureRead,
            courseProvider: { id in try await self.rawFetchCourse(id) }
        )

        if useMocks {
            return await MockDiscussionStore.shared.pipelineStatus()
        }
        return try await request("system/pipeline-health", method: "GET")
    }

    /// Cloudflare + iCloud storage readiness for admin/user data flows.
    func fetchStorageBackendsStatus() async throws -> StorageBackendsStatus {
        let snapshot = try await resolveIdentitySnapshot()
        try await WCSPlatformAccessPolicy.assertAllowed(
            snapshot: snapshot,
            operation: .adminInfrastructureRead,
            courseProvider: { id in try await self.rawFetchCourse(id) }
        )

        if useMocks {
            return StorageArchitectureMockFactory.makeStatus()
        }
        return try await request("system/storage-backends", method: "GET")
    }

    /// Canonical database layout the backend publishes for app compatibility.
    func fetchDatabaseBlueprint() async throws -> DatabaseBlueprint {
        let snapshot = try await resolveIdentitySnapshot()
        try await WCSPlatformAccessPolicy.assertAllowed(
            snapshot: snapshot,
            operation: .adminInfrastructureRead,
            courseProvider: { id in try await self.rawFetchCourse(id) }
        )

        if useMocks {
            return StorageArchitectureMockFactory.makeBlueprint()
        }
        return try await request("system/database-blueprint", method: "GET")
    }

    /// End-to-end capability checks for course/audio/video generation systems.
    func fetchGenerationCapabilityStatus() async -> GenerationCapabilityStatus {
        var checks: [GenerationCapabilityCheck] = []

        let snapshot: WCSIdentitySnapshot
        do {
            snapshot = try await resolveIdentitySnapshot()
        } catch {
            return GenerationCapabilityStatus(
                checkedAt: Date(),
                checks: [
                    GenerationCapabilityCheck(
                        system: "WCS Platform (identity)",
                        state: .offline,
                        detail: "Could not resolve an authenticated user for diagnostics."
                    )
                ]
            )
        }

        do {
            try await WCSPlatformAccessPolicy.assertAllowed(
                snapshot: snapshot,
                operation: .adminInfrastructureRead,
                courseProvider: { id in try await self.rawFetchCourse(id) }
            )
        } catch {
            return GenerationCapabilityStatus(
                checkedAt: Date(),
                checks: [
                    GenerationCapabilityCheck(
                        system: "WCS Platform (administrator access)",
                        state: .offline,
                        detail: "Administrator privileges are required to run generation diagnostics."
                    )
                ]
            )
        }

        let openLibrary = await probeReachability("https://openlibrary.org/search.json?q=education&limit=1")
        checks.append(
            GenerationCapabilityCheck(
                system: "Open Library (course references)",
                state: openLibrary ? .online : .offline,
                detail: openLibrary ? "Reachable" : "Unavailable"
            )
        )

        let openAlex = await probeReachability("https://api.openalex.org/works?search=education&per-page=1")
        checks.append(
            GenerationCapabilityCheck(
                system: "OpenAlex (course references)",
                state: openAlex ? .online : .offline,
                detail: openAlex ? "Reachable" : "Unavailable"
            )
        )

        if YouTubeSearchAPIClient.resolveAPIKey() != nil {
            let youtubeReachable = (try? await YouTubeSearchAPIClient.searchVideos(query: "learning", maxResults: 1)) != nil
            checks.append(
                GenerationCapabilityCheck(
                    system: "YouTube Data API v3",
                    state: youtubeReachable ? .online : .offline,
                    detail: youtubeReachable ? "Key configured + API reachable" : "Key configured but request failed"
                )
            )
        } else {
            checks.append(
                GenerationCapabilityCheck(
                    system: "YouTube Data API v3",
                    state: .missingConfig,
                    detail: "Missing YOUTUBE_DATA_API_KEY"
                )
            )
        }

        checks.append(providerKeyStatus("OPENAI_API_KEY", label: "OpenAI (audio/video generation)"))
        checks.append(providerKeyStatus("REPLICATE_API_TOKEN", label: "Replicate (video/image generation)"))
        checks.append(providerKeyStatus("STABILITY_API_KEY", label: "Stability AI (image generation)"))
        checks.append(providerKeyStatus("GOOGLE_CLOUD_PROJECT_ID", label: "Google Cloud project"))
        checks.append(providerKeyStatus("GOOGLE_OAUTH_CLIENT_ID", label: "Google OAuth client"))
        checks.append(providerKeyStatus("GOOGLE_OAUTH_ACCESS_TOKEN", label: "Google OAuth access token"))

        let gcpProject = ProcessInfo.processInfo.environment["GOOGLE_CLOUD_PROJECT_ID"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
            ? ProcessInfo.processInfo.environment["GOOGLE_CLOUD_PROJECT_ID"]!.trimmingCharacters(in: .whitespacesAndNewlines)
            : "wcs-platform"
        let cloudAICompanion = await probeReachability("https://cloudaicompanion.googleapis.com/v1/projects/\(gcpProject)/locations")
        checks.append(
            GenerationCapabilityCheck(
                system: "Google Cloud AI Companion API",
                state: cloudAICompanion ? .online : .offline,
                detail: cloudAICompanion
                    ? "Endpoint reachable for project \(gcpProject). OAuth token required for authorized calls."
                    : "Endpoint unreachable for project \(gcpProject)"
            )
        )

        return GenerationCapabilityStatus(checkedAt: Date(), checks: checks)
    }

    /// Probe Google Cloud AI Companion supported locations for the configured project.
    /// Requires `GOOGLE_CLOUD_PROJECT_ID` and optionally `GOOGLE_OAUTH_ACCESS_TOKEN` for authorized responses.
    func fetchCloudAICompanionLocations() async throws -> [String] {
        let projectID = ProcessInfo.processInfo.environment["GOOGLE_CLOUD_PROJECT_ID"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
            ? ProcessInfo.processInfo.environment["GOOGLE_CLOUD_PROJECT_ID"]!.trimmingCharacters(in: .whitespacesAndNewlines)
            : "wcs-platform"
        struct LocationsEnvelope: Decodable {
            struct Location: Decodable { let name: String }
            let locations: [Location]?
        }
        let decoded: LocationsEnvelope = try await cloudAICompanionRequest(
            path: "/v1/projects/\(projectID)/locations",
            method: "GET"
        )
        return (decoded.locations ?? []).map(\.name)
    }

    /// Lists repository groups for a Cloud AI Companion code repository index.
    /// Example parent: `projects/wcs-platform/locations/global/codeRepositoryIndexes/my-index`
    func listCloudAIRepositoryGroups(parentIndexResource: String) async throws -> [CloudAIRepositoryGroup] {
        let escapedParent = parentIndexResource.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? parentIndexResource
        let response: CloudAIRepositoryGroupListResponse = try await cloudAICompanionRequest(
            path: "/v1/\(escapedParent)/repositoryGroups",
            method: "GET"
        )
        return response.repositoryGroups ?? []
    }

    /// Gets a single Cloud AI Companion repository group.
    /// Example name: `projects/wcs-platform/locations/global/codeRepositoryIndexes/my-index/repositoryGroups/my-group`
    func getCloudAIRepositoryGroup(name: String) async throws -> CloudAIRepositoryGroup {
        let escapedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return try await cloudAICompanionRequest(path: "/v1/\(escapedName)", method: "GET")
    }

    /// Creates a repository group in Cloud AI Companion.
    /// Example parent: `projects/wcs-platform/locations/global/codeRepositoryIndexes/my-index`
    func createCloudAIRepositoryGroup(
        parentIndexResource: String,
        group: CloudAIRepositoryGroup
    ) async throws -> CloudAIRepositoryGroup {
        let escapedParent = parentIndexResource.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? parentIndexResource
        let body = try jsonEncoder.encode(group)
        return try await cloudAICompanionRequest(
            path: "/v1/\(escapedParent)/repositoryGroups",
            method: "POST",
            body: body
        )
    }

    /// Updates a repository group using PATCH.
    /// `updateMask` should include fields such as `labels` or `repositories`.
    func patchCloudAIRepositoryGroup(
        group: CloudAIRepositoryGroup,
        updateMask: String
    ) async throws -> CloudAIRepositoryGroup {
        let escapedName = group.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? group.name
        let escapedMask = updateMask.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? updateMask
        let body = try jsonEncoder.encode(group)
        return try await cloudAICompanionRequest(
            path: "/v1/\(escapedName)?updateMask=\(escapedMask)",
            method: "PATCH",
            body: body
        )
    }

    /// Deletes a repository group.
    func deleteCloudAIRepositoryGroup(name: String) async throws {
        let escapedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        struct EmptyResponse: Decodable {}
        _ = try await cloudAICompanionRequest(
            path: "/v1/\(escapedName)",
            method: "DELETE"
        ) as EmptyResponse
    }

    /// One-shot automation helper:
    /// - fetch locations
    /// - list repository groups for index
    /// - create target group if missing
    /// - return latest groups + action summary
    func ensureCloudAIRepositoryGroup(
        parentIndexResource: String,
        targetGroup: CloudAIRepositoryGroup
    ) async throws -> CloudAIRepositoryGroupAutomationResult {
        let locations = try await fetchCloudAICompanionLocations()
        var groups = try await listCloudAIRepositoryGroups(parentIndexResource: parentIndexResource)
        let normalizedTarget = targetGroup.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let exists = groups.contains { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedTarget }
        var action = "existing"
        if !exists {
            _ = try await createCloudAIRepositoryGroup(parentIndexResource: parentIndexResource, group: targetGroup)
            groups = try await listCloudAIRepositoryGroups(parentIndexResource: parentIndexResource)
            action = "created"
        }
        return CloudAIRepositoryGroupAutomationResult(
            locations: locations,
            groups: groups,
            action: action
        )
    }

    private func cloudAICompanionRequest<T: Decodable>(
        path: String,
        method: String,
        body: Data? = nil
    ) async throws -> T {
        let snapshot = try await resolveIdentitySnapshot()
        let op: WCSPlatformAccessPolicy.Operation = {
            switch method.uppercased() {
            case "GET":
                return .adminInfrastructureRead
            default:
                return .adminInfrastructureWrite
            }
        }()
        try await WCSPlatformAccessPolicy.assertAllowed(
            snapshot: snapshot,
            operation: op,
            courseProvider: { id in try await self.rawFetchCourse(id) }
        )

        let fullURL = "https://cloudaicompanion.googleapis.com\(path)"
        guard let url = URL(string: fullURL) else {
            throw WCSAPIError(underlying: URLError(.badURL), statusCode: nil, body: nil)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        if let token = ProcessInfo.processInfo.environment["GOOGLE_OAUTH_ACCESS_TOKEN"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw WCSAPIError(underlying: URLError(.badServerResponse), statusCode: nil, body: data)
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw WCSAPIError(underlying: HTTPStatusError(status: http.statusCode), statusCode: http.statusCode, body: data)
        }
        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            throw WCSAPIError(underlying: error, statusCode: http.statusCode, body: data)
        }
    }

    private func providerKeyStatus(_ envKey: String, label: String) -> GenerationCapabilityCheck {
        let value = ProcessInfo.processInfo.environment[envKey]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.isEmpty {
            return GenerationCapabilityCheck(system: label, state: .missingConfig, detail: "Missing \(envKey)")
        }
        return GenerationCapabilityCheck(system: label, state: .configured, detail: "\(envKey) configured")
    }

    private func probeReachability(_ rawURL: String) async -> Bool {
        guard let url = URL(string: rawURL) else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.httpMethod = "GET"
        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200 ..< 500).contains(http.statusCode)
        } catch {
            return false
        }
    }
}

struct GenerationCapabilityStatus: Sendable {
    let checkedAt: Date
    let checks: [GenerationCapabilityCheck]
}

struct GenerationCapabilityCheck: Identifiable, Sendable {
    enum State: String, Sendable {
        case online
        case configured
        case missingConfig
        case offline
    }

    let id = UUID()
    let system: String
    let state: State
    let detail: String
}

struct CloudAIRepositoryGroup: Codable, Hashable {
    struct Repository: Codable, Hashable {
        let resource: String
        let branchPattern: String
    }

    let name: String
    let createTime: String?
    let updateTime: String?
    let labels: [String: String]?
    let repositories: [Repository]
}

private struct CloudAIRepositoryGroupListResponse: Decodable {
    let repositoryGroups: [CloudAIRepositoryGroup]?
}

struct CloudAIRepositoryGroupAutomationResult: Sendable {
    let locations: [String]
    let groups: [CloudAIRepositoryGroup]
    /// "created" when the target group was created, otherwise "existing".
    let action: String
}
