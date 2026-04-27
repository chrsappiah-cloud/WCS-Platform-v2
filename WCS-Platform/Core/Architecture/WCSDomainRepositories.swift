//
//  WCSDomainRepositories.swift
//  WCS-Platform
//
//  Domain-level repository interfaces + live adapters.
//
//  Build membership: this file sits under the `WCS-Platform` synchronized root in Xcode, so it is
//  part of the WCS-Platform app target without a manual PBXFileReference. Use `WCSAppContainer`
//  from SwiftUI/view models to reach the live `NetworkClient`-backed repositories.
//

import Foundation

protocol IdentityRepository {
    func currentUser() async throws -> User
    func signUp(email: String, password: String, displayName: String) async throws -> User
    func logIn(email: String, password: String) async throws -> User
    func switchOrganization(_ organizationId: UUID) async throws -> User
}

protocol CatalogRepository {
    func fetchDiscoverPayload() async throws -> DiscoverPayload
    func fetchAvailableCourses() async throws -> [Course]
    func fetchCourse(_ id: UUID) async throws -> Course
}

protocol LearningRepository {
    func enroll(programId: UUID) async throws -> Enrollment
    func markProgress(programId: UUID, moduleId: UUID, lessonId: UUID, complete: Bool) async throws -> Enrollment
    func submitQuiz(quizId: UUID, answers: [UUID: Int], courseId: UUID?, moduleId: UUID?, lessonId: UUID?) async throws -> QuizSubmissionResult
    func submitAssignment(
        assignmentId: UUID,
        content: String?,
        attachments: [URL],
        courseId: UUID,
        moduleId: UUID,
        lessonId: UUID
    ) async throws -> Submission
}

protocol CommunityRepository {
    func fetchDiscussionFeed(topicID: String?) async throws -> DiscussionFeedResponse
    func createDiscussionPost(topicID: String, body: String, authorName: String) async throws -> DiscussionPost
    func fetchPipelineHealthStatus() async throws -> PipelineHealthStatus
}

protocol CommerceRepository {
    func canAccessProgram(_ course: Course, user: User) -> Bool
    func fetchSubscriptionPlans() async throws -> [WCSSubscriptionPlan]
    func fetchAdminFinanceSnapshot() async throws -> WCSAdminFinanceSnapshot
}

protocol ContentOpsRepository {
    func publishDraft(_ id: UUID) async throws
}

protocol AnalyticsRepository {
    func recentTelemetry(limit: Int) -> [String]
}

nonisolated struct WCSLiveRepositories: IdentityRepository, CatalogRepository, LearningRepository, CommunityRepository, CommerceRepository, ContentOpsRepository, AnalyticsRepository {
    private let client: NetworkClient

    init(client: NetworkClient) {
        self.client = client
    }

    // Identity
    func currentUser() async throws -> User { try await client.currentUser() }
    func signUp(email: String, password: String, displayName: String) async throws -> User {
        try await client.signUp(email: email, password: password, displayName: displayName)
    }
    func logIn(email: String, password: String) async throws -> User {
        try await client.logIn(email: email, password: password)
    }
    func switchOrganization(_ organizationId: UUID) async throws -> User {
        try await client.switchOrganization(organizationId)
    }

    // Catalog
    func fetchDiscoverPayload() async throws -> DiscoverPayload { try await client.fetchDiscoverPayload() }
    func fetchAvailableCourses() async throws -> [Course] { try await client.fetchAvailableCourses() }
    func fetchCourse(_ id: UUID) async throws -> Course { try await client.fetchCourse(id) }

    // Learning
    func enroll(programId: UUID) async throws -> Enrollment { try await client.enroll(programId: programId) }
    func markProgress(programId: UUID, moduleId: UUID, lessonId: UUID, complete: Bool) async throws -> Enrollment {
        try await client.markProgress(programId: programId, moduleId: moduleId, lessonId: lessonId, complete: complete)
    }
    func submitQuiz(quizId: UUID, answers: [UUID: Int], courseId: UUID?, moduleId: UUID?, lessonId: UUID?) async throws -> QuizSubmissionResult {
        try await client.submitQuiz(quizId, answers: answers, courseId: courseId, moduleId: moduleId, lessonId: lessonId)
    }
    func submitAssignment(
        assignmentId: UUID,
        content: String?,
        attachments: [URL],
        courseId: UUID,
        moduleId: UUID,
        lessonId: UUID
    ) async throws -> Submission {
        try await client.submitAssignment(
            assignmentId,
            content: content,
            attachments: attachments,
            courseId: courseId,
            moduleId: moduleId,
            lessonId: lessonId
        )
    }

    // Community
    func fetchDiscussionFeed(topicID: String?) async throws -> DiscussionFeedResponse {
        try await client.fetchDiscussionFeed(topicID: topicID)
    }
    func createDiscussionPost(topicID: String, body: String, authorName: String) async throws -> DiscussionPost {
        try await client.createDiscussionPost(topicID: topicID, body: body, authorName: authorName)
    }
    func fetchPipelineHealthStatus() async throws -> PipelineHealthStatus {
        try await client.fetchPipelineHealthStatus()
    }

    // Commerce
    func canAccessProgram(_ course: Course, user: User) -> Bool {
        client.canAccessProgram(course, user: user)
    }
    func fetchSubscriptionPlans() async throws -> [WCSSubscriptionPlan] {
        try await client.fetchSubscriptionPlans()
    }
    func fetchAdminFinanceSnapshot() async throws -> WCSAdminFinanceSnapshot {
        try await client.fetchAdminFinanceSnapshot()
    }

    // Content ops
    func publishDraft(_ id: UUID) async throws {
        try await client.publishDraft(id)
    }

    // Analytics
    func recentTelemetry(limit: Int) -> [String] {
        Telemetry.recentEvents(limit: limit)
    }
}

nonisolated final class WCSAppContainer {
    static let shared = WCSAppContainer(live: NetworkClient.shared)

    let identity: IdentityRepository
    let catalog: CatalogRepository
    let learning: LearningRepository
    let community: CommunityRepository
    let commerce: CommerceRepository
    let contentOps: ContentOpsRepository
    let analytics: AnalyticsRepository

    init(
        identity: IdentityRepository,
        catalog: CatalogRepository,
        learning: LearningRepository,
        community: CommunityRepository,
        commerce: CommerceRepository,
        contentOps: ContentOpsRepository,
        analytics: AnalyticsRepository
    ) {
        self.identity = identity
        self.catalog = catalog
        self.learning = learning
        self.community = community
        self.commerce = commerce
        self.contentOps = contentOps
        self.analytics = analytics
    }

    convenience init(live client: NetworkClient) {
        let live = WCSLiveRepositories(client: client)
        self.init(
            identity: live,
            catalog: live,
            learning: live,
            community: live,
            commerce: live,
            contentOps: live,
            analytics: live
        )
    }
}

