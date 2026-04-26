//
//  NetworkClient.swift
//  WCS-Platform
//

import Foundation

/// REST shell with a mock path for local UI development. Point `AppEnvironment.platformAPIBaseURL` at your WCS API when ready.
final class NetworkClient {
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

    private func broadcastLearningChange() {
        Task { @MainActor in
            NotificationCenter.default.post(name: .wcsLearningStateDidChange, object: nil)
        }
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
        return try await request("users/me", method: "GET")
    }

    func fetchAvailableCourses() async throws -> [Course] {
        if useMocks {
            try await Task.sleep(nanoseconds: 180_000_000)
            let user = await MockLearningStore.shared.currentUser()
            return await MockLearningStore.shared.snapshotCourses(forPremiumUser: user.isPremium)
        }
        let response: CourseListResponse = try await request("courses/available", method: "GET")
        return response.courses
    }

    func fetchCourse(_ courseId: UUID) async throws -> Course {
        if useMocks {
            try await Task.sleep(nanoseconds: 120_000_000)
            guard let course = await MockLearningStore.shared.snapshotCourse(courseId) else {
                throw WCSAPIError(underlying: URLError(.fileDoesNotExist), statusCode: 404, body: nil)
            }
            return course
        }
        return try await request("courses/\(courseId.uuidString)", method: "GET")
    }

    func enrollInCourse(_ courseId: UUID) async throws -> Enrollment {
        if useMocks {
            try await Task.sleep(nanoseconds: 160_000_000)
            return await MockLearningStore.shared.enroll(courseId)
        }
        let encoded = try jsonEncoder.encode(EnrollmentCreateRequest(courseId: courseId))
        let result: Enrollment = try await request("enrollments", method: "POST", body: encoded)
        broadcastLearningChange()
        return result
    }

    func updateLessonProgress(
        courseId: UUID,
        moduleId: UUID,
        lessonId: UUID,
        complete: Bool
    ) async throws -> Enrollment {
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

    func submitQuiz(_ quizId: UUID, answers: [UUID: Int]) async throws -> QuizSubmissionResult {
        if useMocks {
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
            return QuizSubmissionResult(
                score: score,
                total: total,
                percentage: percentage,
                oxfordGrade: grade,
                isPassed: passed,
                passedAt: passed ? Date() : nil,
                feedback: passed ? "Great work. You are eligible for certification." : "Review the explanations and try again.",
                certification: certificate
            )
        }
        let encoded = try jsonEncoder.encode(QuizSubmissionRequest(quizId: quizId, answers: answers))
        return try await request("quizzes/\(quizId.uuidString)/submit", method: "POST", body: encoded)
    }

    func submitAssignment(_ assignmentId: UUID, content: String?, attachments: [URL]) async throws -> Submission {
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
        if useMocks {
            try await Task.sleep(nanoseconds: 120_000_000)
            return await MockDiscussionStore.shared.feed(topicID: topicID)
        }
        let query = topicID.map { "?topic=\($0)" } ?? ""
        return try await request("discussion/feed\(query)", method: "GET")
    }

    func createDiscussionPost(topicID: String, body: String, authorName: String) async throws -> DiscussionPost {
        if useMocks {
            try await Task.sleep(nanoseconds: 100_000_000)
            return await MockDiscussionStore.shared.createPost(topicID: topicID, body: body, authorName: authorName)
        }
        let encoded = try jsonEncoder.encode(DiscussionCreateRequest(topicID: topicID, body: body))
        return try await request("discussion/posts", method: "POST", body: encoded)
    }

    func fetchPipelineHealthStatus() async throws -> PipelineHealthStatus {
        if useMocks {
            return await MockDiscussionStore.shared.pipelineStatus()
        }
        return try await request("system/pipeline-health", method: "GET")
    }

    /// Cloudflare + iCloud storage readiness for admin/user data flows.
    func fetchStorageBackendsStatus() async throws -> StorageBackendsStatus {
        if useMocks {
            return StorageArchitectureMockFactory.makeStatus()
        }
        return try await request("system/storage-backends", method: "GET")
    }

    /// Canonical database layout the backend publishes for app compatibility.
    func fetchDatabaseBlueprint() async throws -> DatabaseBlueprint {
        if useMocks {
            return StorageArchitectureMockFactory.makeBlueprint()
        }
        return try await request("system/database-blueprint", method: "GET")
    }

    /// End-to-end capability checks for course/audio/video generation systems.
    func fetchGenerationCapabilityStatus() async -> GenerationCapabilityStatus {
        var checks: [GenerationCapabilityCheck] = []

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
        guard let url = URL(string: "https://cloudaicompanion.googleapis.com/v1/projects/\(projectID)/locations") else {
            throw WCSAPIError(underlying: URLError(.badURL), statusCode: nil, body: nil)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
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
        struct LocationsEnvelope: Decodable {
            struct Location: Decodable { let name: String }
            let locations: [Location]?
        }
        let decoded = try jsonDecoder.decode(LocationsEnvelope.self, from: data)
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
