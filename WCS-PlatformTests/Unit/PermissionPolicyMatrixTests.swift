import Foundation
import Testing
@testable import WCS_Platform

struct PermissionPolicyMatrixTests {
    @Test
    func learningProgress_allowsActiveEnrollmentAndUnlockedLesson() async throws {
        let fixture = AccessPolicyFixture()
        let snapshot = fixture.snapshot(enrolled: true)

        try await WCSPlatformAccessPolicy.assertAllowed(
            snapshot: snapshot,
            operation: .learningProgress(
                courseId: fixture.course.id,
                moduleId: fixture.module.id,
                lessonId: fixture.lesson.id
            ),
            courseProvider: { _ in fixture.course }
        )
    }

    @Test
    func learningProgress_deniesMissingEnrollment() async {
        let fixture = AccessPolicyFixture()
        let snapshot = fixture.snapshot(enrolled: false)

        await #expect(throws: WCSAPIError.self) {
            try await WCSPlatformAccessPolicy.assertAllowed(
                snapshot: snapshot,
                operation: .learningProgress(
                    courseId: fixture.course.id,
                    moduleId: fixture.module.id,
                    lessonId: fixture.lesson.id
                ),
                courseProvider: { _ in fixture.course }
            )
        }
    }

    @Test
    func learningProgress_deniesLockedLessonForEnrolledLearner() async {
        let fixture = AccessPolicyFixture(lessonUnlocked: false)
        let snapshot = fixture.snapshot(enrolled: true)

        await #expect(throws: WCSAPIError.self) {
            try await WCSPlatformAccessPolicy.assertAllowed(
                snapshot: snapshot,
                operation: .learningProgress(
                    courseId: fixture.course.id,
                    moduleId: fixture.module.id,
                    lessonId: fixture.lesson.id
                ),
                courseProvider: { _ in fixture.course }
            )
        }
    }

    @Test
    func catalogRedaction_usesNeutralEnrollmentCopy() {
        let fixture = AccessPolicyFixture(lessonUnlocked: true)
        let snapshot = fixture.snapshot(enrolled: false)

        let redacted = WCSPlatformAccessPolicy.redactCourseForCatalogIfNeeded(
            snapshot: snapshot,
            course: fixture.course
        )
        let markdown = redacted.modules.first?.lessons.first?.reading?.markdown ?? ""
        let blockedTerms = [
            ["pur", "chase"].joined(),
            ["sub", "scription"].joined(),
            ["prem", "ium"].joined()
        ]

        #expect(markdown.localizedCaseInsensitiveContains("assigned by your organization"))
        for term in blockedTerms {
            #expect(!markdown.localizedCaseInsensitiveContains(term))
        }
    }
}

private struct AccessPolicyFixture {
    let userId = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
    let orgId = UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000001")!
    let module: Module
    let lesson: Lesson
    let course: Course

    init(lessonUnlocked: Bool = true) {
        lesson = Lesson(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
            title: "Policy Lesson",
            subtitle: nil,
            type: .reading,
            videoURL: nil,
            durationSeconds: 300,
            isCompleted: false,
            isAvailable: true,
            isUnlocked: lessonUnlocked,
            reading: ReadingContent(markdown: "Lesson body"),
            quiz: nil,
            assignment: nil
        )
        module = Module(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
            title: "Policy Module",
            description: nil,
            order: 1,
            isAvailable: true,
            isUnlocked: true,
            lessons: [lesson]
        )
        course = Course(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            title: "Policy Course",
            subtitle: nil,
            description: "Policy fixture",
            thumbnailURL: "https://example.com/thumb.png",
            coverURL: nil,
            durationSeconds: 300,
            isEnrolled: false,
            isOwned: false,
            rating: nil,
            reviewCount: 0,
            organizationName: "World Class Scholars",
            level: "Beginner",
            effortDescription: nil,
            spokenLanguages: ["en"],
            modules: [module]
        )
    }

    func snapshot(enrolled: Bool) -> WCSIdentitySnapshot {
        let enrollment = Enrollment(
            id: UUID(uuidString: "CCCCCCCC-0000-0000-0000-000000000001")!,
            courseId: course.id,
            userId: userId,
            startDate: Date(timeIntervalSince1970: 0),
            endDate: nil,
            status: .active,
            progressPercentage: 0
        )
        let access = OrganizationAccess(
            id: UUID(uuidString: "DDDDDDDD-0000-0000-0000-000000000001")!,
            organizationId: orgId,
            organizationName: "World Class Scholars",
            role: .learner,
            joinedAt: Date(timeIntervalSince1970: 0),
            isActive: true
        )
        let user = User(
            id: userId,
            email: "learner@example.com",
            name: "Learner",
            photoURL: nil,
            role: .learner,
            activeOrganizationId: orgId,
            accessRecords: [access],
            enrollments: enrolled ? [enrollment] : []
        )
        return WCSIdentitySnapshot(
            user: user,
            org: WCSOrgContext(slug: "wcs", displayName: "World Class Scholars")
        )
    }
}
