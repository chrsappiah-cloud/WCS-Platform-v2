//
//  WCSPlatformAccessControl.swift
//  WCS-Platform
//
//  Client-side policy enforcement for WCS domains. This is not a substitute for server authorization,
//  but it keeps the iOS client aligned with multi-tenant + commerce + learning coupling assumptions.
//

import Foundation

struct WCSOrgContext: Sendable, Hashable {
    /// Stable tenant key derived from catalog metadata until explicit org ids exist in API models.
    let slug: String
    let displayName: String?

    nonisolated static func derived(from course: Course) -> WCSOrgContext {
        let name = course.organizationName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty {
            let slug = Self.slugify(name)
            return WCSOrgContext(slug: slug, displayName: name)
        }
        return WCSOrgContext(slug: "wcs-global", displayName: "World Class Scholars")
    }

    private nonisolated static func slugify(_ value: String) -> String {
        let lower = value.lowercased()
        let mapped = lower.map { ch -> Character in
            guard let scalar = ch.unicodeScalars.first else { return "-" }
            if CharacterSet.alphanumerics.contains(scalar) { return ch }
            return "-"
        }
        let collapsed = String(mapped)
            .replacingOccurrences(of: "--", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return collapsed.isEmpty ? "wcs-org" : collapsed
    }
}

struct WCSIdentitySnapshot: Sendable {
    let user: User
    let org: WCSOrgContext

    nonisolated var isPremium: Bool { user.isPremium }
    nonisolated var isAdmin: Bool { user.isAdmin }

    nonisolated func telemetryAttributes() -> [String: String] {
        [
            "orgSlug": org.slug,
            "userId": user.id.uuidString,
            "userRole": user.role.rawValue,
        ]
    }
}

enum WCSCommunityAnchor: Sendable, Hashable {
    case lesson(courseId: UUID, moduleId: UUID, lessonId: UUID)

    nonisolated static func parse(topicID: String) -> WCSCommunityAnchor? {
        let trimmed = topicID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Supported formats:
        // - wcs:anchor:course:<uuid>:module:<uuid>:lesson:<uuid>
        // - course:<uuid>/module:<uuid>/lesson:<uuid>
        if trimmed.lowercased().hasPrefix("wcs:anchor:") {
            return parseKeyedPrefix(trimmed)
        }
        if trimmed.lowercased().contains("course:"), trimmed.lowercased().contains("lesson:") {
            return parseSlashedFormat(trimmed)
        }
        return nil
    }

    private nonisolated static func parseKeyedPrefix(_ raw: String) -> WCSCommunityAnchor? {
        let parts = raw.split(separator: ":").map(String.init)
        // ["wcs","anchor","course",uuid,"module",uuid,"lesson",uuid]
        guard parts.count >= 8 else { return nil }
        guard parts[0].lowercased() == "wcs" else { return nil }
        guard parts[1].lowercased() == "anchor" else { return nil }

        var course: UUID?
        var module: UUID?
        var lesson: UUID?

        var idx = 2
        while idx + 1 < parts.count {
            let key = parts[idx].lowercased()
            let value = parts[idx + 1]
            switch key {
            case "course":
                course = UUID(uuidString: value)
            case "module":
                module = UUID(uuidString: value)
            case "lesson":
                lesson = UUID(uuidString: value)
            default:
                break
            }
            idx += 2
        }

        if let course, let module, let lesson {
            return .lesson(courseId: course, moduleId: module, lessonId: lesson)
        }
        return nil
    }

    private nonisolated static func parseSlashedFormat(_ raw: String) -> WCSCommunityAnchor? {
        // course:<uuid>/module:<uuid>/lesson:<uuid>
        let segments = raw.split(separator: "/").map(String.init)
        var course: UUID?
        var module: UUID?
        var lesson: UUID?

        for segment in segments {
            let pair = segment.split(separator: ":", maxSplits: 1).map(String.init)
            guard pair.count == 2 else { continue }
            let key = pair[0].lowercased()
            let value = pair[1]
            switch key {
            case "course":
                course = UUID(uuidString: value)
            case "module":
                module = UUID(uuidString: value)
            case "lesson":
                lesson = UUID(uuidString: value)
            default:
                break
            }
        }

        if let course, let module, let lesson {
            return .lesson(courseId: course, moduleId: module, lessonId: lesson)
        }
        return nil
    }
}

enum WCSPlatformAccessPolicy: Sendable {
    enum Operation: Sendable {
        case catalogBrowse
        case catalogCourseDetail(courseId: UUID)
        case learningProgress(courseId: UUID, moduleId: UUID, lessonId: UUID)
        case learningQuizSubmit(courseId: UUID, moduleId: UUID, lessonId: UUID, quizId: UUID)
        case learningAssignmentSubmit(courseId: UUID, moduleId: UUID, lessonId: UUID, assignmentId: UUID)
        case communityFeed(topicID: String?)
        case communityPost(topicID: String)
        case commerceEnroll(courseId: UUID)
        case commercePlansRead
        case commerceAdminFinanceRead
        case adminInfrastructureRead
        case adminInfrastructureWrite
    }

    nonisolated static func identitySnapshot(useMocks: Bool, bootstrapUserRequest: () async throws -> User) async throws -> WCSIdentitySnapshot {
        if useMocks {
            let user = await MockLearningStore.shared.currentUser()
            return WCSIdentitySnapshot(
                user: user,
                org: WCSOrgContext(slug: "wcs-global", displayName: "World Class Scholars")
            )
        }

        let token = UserDefaults.standard.string(forKey: "wcs.authToken")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !token.isEmpty else {
            throw WCSAPIError(underlying: URLError(.userAuthenticationRequired), statusCode: 401, body: nil)
        }

        let user = try await bootstrapUserRequest()
        return WCSIdentitySnapshot(
            user: user,
            org: WCSOrgContext(slug: "wcs-global", displayName: "World Class Scholars")
        )
    }

    nonisolated static func assertAllowed(
        snapshot: WCSIdentitySnapshot,
        operation: Operation,
        courseProvider: (UUID) async throws -> Course
    ) async throws {
        switch operation {
        case .catalogBrowse:
            try assertIdentityPresent(snapshot)
            return

        case let .catalogCourseDetail(courseId):
            try assertIdentityPresent(snapshot)
            _ = try await courseProvider(courseId)
            return

        case let .commerceEnroll(courseId):
            try assertIdentityPresent(snapshot)
            let course = try await courseProvider(courseId)
            try assertCanPurchaseOrEnroll(snapshot: snapshot, course: course)

        case .commercePlansRead:
            try assertIdentityPresent(snapshot)
            return

        case .commerceAdminFinanceRead:
            try assertIdentityPresent(snapshot)
            guard snapshot.isAdmin else {
                throw WCSAPIError(underlying: URLError(.dataNotAllowed), statusCode: 403, body: nil)
            }
            return

        case let .learningProgress(courseId, moduleId, lessonId):
            try assertIdentityPresent(snapshot)
            let course = try await courseProvider(courseId)
            try assertEnrolled(snapshot: snapshot, courseId: courseId)
            let lesson = try requireLesson(course: course, moduleId: moduleId, lessonId: lessonId)
            try assertLessonUnlocked(lesson)

        case let .learningQuizSubmit(courseId, moduleId, lessonId, quizId):
            try assertIdentityPresent(snapshot)
            let course = try await courseProvider(courseId)
            try assertEnrolled(snapshot: snapshot, courseId: courseId)
            let lesson = try requireLesson(course: course, moduleId: moduleId, lessonId: lessonId)
            try assertLessonUnlocked(lesson)
            guard lesson.quiz?.id == quizId else {
                throw WCSAPIError(underlying: URLError(.dataNotAllowed), statusCode: 403, body: nil)
            }

        case let .learningAssignmentSubmit(courseId, moduleId, lessonId, assignmentId):
            try assertIdentityPresent(snapshot)
            let course = try await courseProvider(courseId)
            try assertEnrolled(snapshot: snapshot, courseId: courseId)
            let lesson = try requireLesson(course: course, moduleId: moduleId, lessonId: lessonId)
            try assertLessonUnlocked(lesson)
            guard lesson.assignment?.id == assignmentId else {
                throw WCSAPIError(underlying: URLError(.dataNotAllowed), statusCode: 403, body: nil)
            }

        case let .communityFeed(topicID):
            try assertIdentityPresent(snapshot)
            if let topicID, let anchor = WCSCommunityAnchor.parse(topicID: topicID) {
                switch anchor {
                case let .lesson(courseId, moduleId, lessonId):
                    let course = try await courseProvider(courseId)
                    let lesson = try requireLesson(course: course, moduleId: moduleId, lessonId: lessonId)
                    // Feed reads follow the same visibility rules as lesson materials (preview allowed when not enrolled).
                    _ = accessMode(snapshot: snapshot, course: course, lesson: lesson)
                }
            }

        case let .communityPost(topicID):
            try assertIdentityPresent(snapshot)
            guard let anchor = WCSCommunityAnchor.parse(topicID: topicID) else {
                // Global topics still require a signed-in identity (handled above).
                return
            }
            switch anchor {
            case let .lesson(courseId, moduleId, lessonId):
                let course = try await courseProvider(courseId)
                try assertEnrolled(snapshot: snapshot, courseId: courseId)
                let lesson = try requireLesson(course: course, moduleId: moduleId, lessonId: lessonId)
                try assertLessonUnlocked(lesson)
            }

        case .adminInfrastructureRead, .adminInfrastructureWrite:
            try assertIdentityPresent(snapshot)
            guard snapshot.isAdmin else {
                throw WCSAPIError(underlying: URLError(.dataNotAllowed), statusCode: 403, body: nil)
            }
            return
        }
    }

    nonisolated static func redactCourseForCatalogIfNeeded(snapshot: WCSIdentitySnapshot, course: Course) -> Course {
        if canViewFullCourse(snapshot: snapshot, course: course) {
            return course
        }
        return redactCourse(course)
    }

    // MARK: - Internals

    private nonisolated static func assertIdentityPresent(_ snapshot: WCSIdentitySnapshot) throws {
        // `User.id` is always present; email acts as the lightweight "signed in" signal for mock + live shells.
        guard !snapshot.user.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WCSAPIError(underlying: URLError(.userAuthenticationRequired), statusCode: 401, body: nil)
        }
        let hasActiveMembership = snapshot.user.memberships.isEmpty || snapshot.user.memberships.contains(where: { $0.isActive })
        guard hasActiveMembership else {
            throw WCSAPIError(underlying: URLError(.userAuthenticationRequired), statusCode: 403, body: nil)
        }
    }

    private nonisolated static func assertEnrolled(snapshot: WCSIdentitySnapshot, courseId: UUID) throws {
        let enrolled = snapshot.user.enrollments.contains(where: { $0.courseId == courseId && $0.status == .active })
        guard enrolled || snapshot.isAdmin else {
            throw WCSAPIError(underlying: URLError(.dataNotAllowed), statusCode: 403, body: nil)
        }
    }

    private nonisolated static func assertLessonUnlocked(_ lesson: Lesson) throws {
        guard lesson.isAvailable, lesson.isUnlocked else {
            throw WCSAPIError(underlying: URLError(.dataNotAllowed), statusCode: 403, body: nil)
        }
    }

    private nonisolated static func assertCanPurchaseOrEnroll(snapshot: WCSIdentitySnapshot, course: Course) throws {
        if course.price == nil { return }
        guard snapshot.isPremium || snapshot.isAdmin else {
            throw WCSAPIError(underlying: URLError(.dataNotAllowed), statusCode: 402, body: nil)
        }
    }

    private nonisolated static func canViewFullCourse(snapshot: WCSIdentitySnapshot, course: Course) -> Bool {
        if snapshot.isAdmin { return true }
        if course.isEnrolled || course.isOwned { return true }
        if course.isUnlockedBySubscription && snapshot.isPremium { return true }
        return false
    }

    private nonisolated static func accessMode(snapshot: WCSIdentitySnapshot, course: Course, lesson: Lesson) -> CatalogAccessMode {
        if snapshot.isAdmin { return .full }
        if course.isEnrolled || course.isOwned { return .full }
        if course.isUnlockedBySubscription {
            return snapshot.isPremium ? .full : .preview
        }
        if course.price != nil {
            return snapshot.isPremium ? .full : .preview
        }
        // Free courses: allow full read of marketing catalog surface, but still block writes elsewhere.
        return .preview
    }

    private enum CatalogAccessMode: Sendable {
        case full
        case preview
    }

    private nonisolated static func requireLesson(course: Course, moduleId: UUID, lessonId: UUID) throws -> Lesson {
        guard let module = course.modules.first(where: { $0.id == moduleId }) else {
            throw WCSAPIError(underlying: URLError(.fileDoesNotExist), statusCode: 404, body: nil)
        }
        guard let lesson = module.lessons.first(where: { $0.id == lessonId }) else {
            throw WCSAPIError(underlying: URLError(.fileDoesNotExist), statusCode: 404, body: nil)
        }
        return lesson
    }

    private nonisolated static func redactCourse(_ course: Course) -> Course {
        let redactedModules = course.modules.map { module in
            Module(
                id: module.id,
                title: module.title,
                description: module.description,
                order: module.order,
                isAvailable: module.isAvailable,
                isUnlocked: module.isUnlocked,
                lessons: module.lessons.map(redactLessonPreview)
            )
        }

        return Course(
            id: course.id,
            title: course.title,
            subtitle: course.subtitle,
            description: course.description,
            thumbnailURL: course.thumbnailURL,
            coverURL: course.coverURL,
            durationSeconds: course.durationSeconds,
            price: course.price,
            isEnrolled: false,
            isOwned: course.isOwned,
            isUnlockedBySubscription: course.isUnlockedBySubscription,
            rating: course.rating,
            reviewCount: course.reviewCount,
            organizationName: course.organizationName,
            level: course.level,
            effortDescription: course.effortDescription,
            spokenLanguages: course.spokenLanguages,
            modules: redactedModules,
            courseReport: nil
        )
    }

    private nonisolated static func redactLessonPreview(_ lesson: Lesson) -> Lesson {
        Lesson(
            id: lesson.id,
            title: lesson.title,
            subtitle: lesson.subtitle,
            type: lesson.type,
            videoURL: nil,
            durationSeconds: lesson.durationSeconds,
            isCompleted: false,
            isAvailable: lesson.isAvailable,
            isUnlocked: false,
            reading: ReadingContent(markdown: "_Preview mode: enroll or upgrade to unlock this lesson._"),
            quiz: nil,
            assignment: nil
        )
    }
}
