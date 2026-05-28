import Foundation
import Testing
@testable import WCS_Platform

struct LearningPersistenceIntegrationTests {
    @Test func enrollThenSaveWatchProgress_survivesCourseSnapshot() async {
        await MockLearningStore.shared.resetLearningStateForTests()
        let courseId = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let lessonId = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!

        _ = await MockLearningStore.shared.enroll(courseId)
        await MockLearningStore.shared.saveWatchProgress(
            courseId: courseId,
            lessonId: lessonId,
            positionSeconds: 88.5
        )

        let hydrated = await MockLearningStore.shared.snapshotCourse(courseId)
        let resume = hydrated?.modules
            .flatMap(\.lessons)
            .first(where: { $0.id == lessonId })?
            .serverResumePositionSeconds

        #expect(resume == 88.5)
    }

    @Test func markProgress_updatesEnrollmentFraction() async throws {
        await MockLearningStore.shared.resetLearningStateForTests()
        let courseId = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let lessonId = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
        _ = await MockLearningStore.shared.enroll(courseId)
        _ = try await MockLearningStore.shared.markProgress(
            courseId: courseId,
            lessonId: lessonId,
            complete: true
        )

        let enrollment = await MockLearningStore.shared.currentUser().enrollments
            .first(where: { $0.courseId == courseId })
        #expect(enrollment != nil)
        #expect((enrollment?.progressPercentage ?? 0) > 0)
    }
}
