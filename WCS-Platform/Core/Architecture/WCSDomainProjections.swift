//
//  WCSDomainProjections.swift
//  WCS-Platform
//
//  Typed cross-domain projections for UI/API composition while preserving bounded context ownership.
//

import Foundation

enum WCSDifficulty: String, Sendable {
    case beginner
    case intermediate
    case advanced
}

struct IdentityProjection: Sendable {
    let userId: UUID
    let role: UserRole
    let activeOrganizationId: UUID?
    let memberships: [OrganizationMembership]
}

struct CatalogProjection: Sendable {
    let courseId: UUID
    let title: String
    let tags: [String]
    let featuredPlacement: Int?
}

struct LearningProjection: Sendable {
    let courseId: UUID
    let progressionPercent: Double
    let estimatedWeeklyHours: Int
    let difficulty: WCSDifficulty
    let assessmentCount: Int
    let completionRule: String
}

struct CommunityProjection: Sendable {
    let topicId: String
    let threadCount: Int
    let moderationEnabled: Bool
    let reportingEnabled: Bool
}

struct CommerceProjection: Sendable {
    let courseId: UUID
    let sku: String
    let price: Decimal?
    let freeToAudit: Bool
    let entitled: Bool
}

struct ProfileProjection: Sendable {
    let userId: UUID
    let completedCourseCount: Int
    let badges: [String]
    let certificatesIssued: Int
}

struct ContentOpsProjection: Sendable {
    let draftId: UUID
    let moduleCount: Int
    let lessonCount: Int
    let publishable: Bool
}

struct AnalyticsProjection: Sendable {
    let funnelEvents: Int
    let retentionSignals: Int
    let completionSignals: Int
    let monetizationSignals: Int
}

enum WCSDomainProjector {
    static func identity(from user: User) -> IdentityProjection {
        IdentityProjection(
            userId: user.id,
            role: user.role,
            activeOrganizationId: user.activeOrganizationId,
            memberships: user.memberships
        )
    }

    static func catalog(from course: Course, tags: [String], featuredPlacement: Int?) -> CatalogProjection {
        CatalogProjection(
            courseId: course.id,
            title: course.title,
            tags: tags,
            featuredPlacement: featuredPlacement
        )
    }

    static func learning(from course: Course, enrollment: Enrollment?) -> LearningProjection {
        let totalLessons = max(1, course.modules.flatMap(\.lessons).count)
        let completedLessons = course.modules.flatMap(\.lessons).filter(\.isCompleted).count
        let progression = Double(completedLessons) / Double(totalLessons)
        let weeklyHours = max(1, Int((Double(course.durationSeconds) / 3600.0 / 6.0).rounded(.up)))
        let difficulty: WCSDifficulty = {
            let normalized = (course.level ?? "").lowercased()
            if normalized.contains("advanced") { return .advanced }
            if normalized.contains("intermediate") { return .intermediate }
            return .beginner
        }()
        let assessments = course.modules.flatMap(\.lessons).filter { $0.quiz != nil || $0.assignment != nil }.count
        let completionRule = "Complete all required lessons and pass graded assessments."
        _ = enrollment // kept as explicit dependency for context ownership.

        return LearningProjection(
            courseId: course.id,
            progressionPercent: progression,
            estimatedWeeklyHours: weeklyHours,
            difficulty: difficulty,
            assessmentCount: assessments,
            completionRule: completionRule
        )
    }

    static func community(topics: [DiscussionTopic], posts: [DiscussionPost]) -> [CommunityProjection] {
        topics.map { topic in
            CommunityProjection(
                topicId: topic.id,
                threadCount: posts.filter { $0.topicID == topic.id }.count,
                moderationEnabled: true,
                reportingEnabled: true
            )
        }
    }

    static func commerce(from course: Course, user: User) -> CommerceProjection {
        let sku = "course-\(course.id.uuidString.lowercased())"
        let entitled = user.isPremium || course.isOwned || course.isEnrolled || (course.price == nil)
        let freeToAudit = course.price != nil && !entitled
        return CommerceProjection(
            courseId: course.id,
            sku: sku,
            price: course.price,
            freeToAudit: freeToAudit,
            entitled: entitled
        )
    }

    static func profile(from user: User) -> ProfileProjection {
        let completed = user.enrollments.filter { $0.status == .completed }.count
        let badges = completed > 0 ? ["Course Completer"] : []
        let certificates = completed
        return ProfileProjection(
            userId: user.id,
            completedCourseCount: completed,
            badges: badges,
            certificatesIssued: certificates
        )
    }

    static func contentOps(from draft: AdminCourseDraft) -> ContentOpsProjection {
        let lessonCount = draft.modules.flatMap(\.lessons).count
        let publishable = !draft.modules.isEmpty && lessonCount > 0 && !draft.outcomes.isEmpty
        return ContentOpsProjection(
            draftId: draft.id,
            moduleCount: draft.modules.count,
            lessonCount: lessonCount,
            publishable: publishable
        )
    }

    static func analytics(from recentTelemetry: [String]) -> AnalyticsProjection {
        let funnel = recentTelemetry.filter { $0.contains("course.load.") || $0.contains("enroll") }.count
        let retention = recentTelemetry.filter { $0.contains("heartbeat") || $0.contains("load.success") }.count
        let completion = recentTelemetry.filter { $0.contains("lesson.video") || $0.contains("certificate_earned") }.count
        let monetization = recentTelemetry.filter { $0.contains("checkout") || $0.contains("purchase") || $0.contains("subscription") }.count
        return AnalyticsProjection(
            funnelEvents: funnel,
            retentionSignals: retention,
            completionSignals: completion,
            monetizationSignals: monetization
        )
    }
}

