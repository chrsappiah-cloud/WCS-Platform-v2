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
}
