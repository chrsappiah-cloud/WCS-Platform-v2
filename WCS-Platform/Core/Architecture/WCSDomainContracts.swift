//
//  WCSDomainContracts.swift
//  WCS-Platform
//
//  Explicit bounded-context contracts used by the iOS client.
//

import Foundation

enum WCSDomain: String, CaseIterable, Sendable {
    case identity
    case catalog
    case learning
    case community
    case commerce
    case profile
    case contentOps
    case analytics
}

enum WCSDomainEntity: String, CaseIterable, Sendable {
    case signupLogin
    case roles
    case organizationMembership
    case programs
    case tags
    case featuredPlacement
    case progression
    case weeklyHours
    case difficulty
    case assessments
    case completionRules
    case threads
    case replies
    case moderation
    case reporting
    case pricing
    case skus
    case purchases
    case subscriptions
    case entitlements
    case learnerProfile
    case badges
    case certificates
    case programAuthoring
    case modulePublishing
    case funnels
    case retention
    case completionMetrics
    case monetizationMetrics
}

struct WCSDomainContract: Sendable, Hashable {
    let domain: WCSDomain
    let owns: Set<WCSDomainEntity>
}

enum WCSDomainRegistry {
    static let contracts: [WCSDomainContract] = [
        WCSDomainContract(
            domain: .identity,
            owns: [.signupLogin, .roles, .organizationMembership]
        ),
        WCSDomainContract(
            domain: .catalog,
            owns: [.programs, .tags, .featuredPlacement]
        ),
        WCSDomainContract(
            domain: .learning,
            owns: [.progression, .weeklyHours, .difficulty, .assessments, .completionRules]
        ),
        WCSDomainContract(
            domain: .community,
            owns: [.threads, .replies, .moderation, .reporting]
        ),
        WCSDomainContract(
            domain: .commerce,
            owns: [.pricing, .skus, .purchases, .subscriptions, .entitlements]
        ),
        WCSDomainContract(
            domain: .profile,
            owns: [.learnerProfile, .badges, .certificates]
        ),
        WCSDomainContract(
            domain: .contentOps,
            owns: [.programAuthoring, .modulePublishing]
        ),
        WCSDomainContract(
            domain: .analytics,
            owns: [.funnels, .retention, .completionMetrics, .monetizationMetrics]
        ),
    ]

    static func owner(of entity: WCSDomainEntity) -> WCSDomain? {
        contracts.first(where: { $0.owns.contains(entity) })?.domain
    }

    static func validateStrictOwnership() -> [String] {
        var errors: [String] = []
        for entity in WCSDomainEntity.allCases {
            let owners = contracts.filter { $0.owns.contains(entity) }.map(\.domain)
            if owners.isEmpty {
                errors.append("No domain owns \(entity.rawValue)")
            } else if owners.count > 1 {
                errors.append("Multiple domains own \(entity.rawValue): \(owners.map(\.rawValue).joined(separator: ", "))")
            }
        }
        return errors
    }
}

// MARK: - Domain-oriented client contracts

protocol IdentityService {
    func signUp(email: String, password: String, displayName: String) async throws -> User
    func logIn(email: String, password: String) async throws -> User
    func switchOrganization(_ organizationId: UUID) async throws -> User
}

protocol CatalogService {
    func discoverPrograms() async throws -> [Course]
    func loadProgram(_ id: UUID) async throws -> Course
}

protocol LearningService {
    func enroll(programId: UUID) async throws -> Enrollment
    func markProgress(programId: UUID, moduleId: UUID, lessonId: UUID, complete: Bool) async throws -> Enrollment
    func saveWatchProgress(
        programId: UUID,
        moduleId: UUID,
        lessonId: UUID,
        positionSeconds: Double,
        durationSeconds: Double
    ) async throws
}

protocol CommunityService {
    func loadDiscussion(topicID: String?) async throws -> DiscussionFeedResponse
    func postDiscussion(topicID: String, body: String, authorName: String) async throws -> DiscussionPost
}

protocol CommerceService {
    func canAccessProgram(_ course: Course, user: User) -> Bool
}

protocol ContentOpsService {
    func publishDraft(_ id: UUID) async throws
    func planLessonVideo(_ request: LessonVideoPlanRequest) async throws -> LessonVideoPlanResponse
    func renderLessonScene(_ sceneId: String, request: LessonVideoSceneRenderRequest) async throws -> LessonVideoRenderJobResponse
    func fetchLessonRenderJob(_ renderJobId: String) async throws -> LessonVideoRenderJobResponse
    func composeLessonVideo(_ lessonId: String, request: LessonVideoComposeRequest) async throws -> LessonVideoComposeResponse
    func fetchLessonVideoOutput(_ lessonId: String) async throws -> LessonVideoOutputResponse
}

