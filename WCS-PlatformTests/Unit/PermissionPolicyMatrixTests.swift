import Foundation
import Testing
@testable import WCS_Platform

struct PermissionPolicyMatrixTests {
    @Test
    func learnerCannotAccessPaidProgramWithoutEntitlement() {
        let paid = makeCourse(title: "Paid", paid: true)
        let learner = makeLearner(isPremium: false, role: .learner)
        #expect(!NetworkClient.shared.canAccessProgram(paid, user: learner))
    }

    @Test
    func premiumLearnerCanAccessPaidProgram() {
        let paid = makeCourse(title: "Paid", paid: true)
        let learner = makeLearner(isPremium: true, role: .learner)
        #expect(NetworkClient.shared.canAccessProgram(paid, user: learner))
    }

    @Test
    func orgAdminCanAccessPaidProgram() {
        let paid = makeCourse(title: "Paid", paid: true)
        let admin = makeLearner(isPremium: false, role: .orgAdmin)
        #expect(NetworkClient.shared.canAccessProgram(paid, user: admin))
    }
}

private func makeLearner(isPremium: Bool, role: UserRole) -> User {
    User(
        id: UUID(),
        email: "learner@wcs.test",
        name: "WCS Learner",
        photoURL: nil,
        role: role,
        activeOrganizationId: nil,
        memberships: [],
        subscriptions: isPremium ? [
            Subscription(
                id: UUID(),
                planId: "premium-monthly",
                planName: "Premium Membership",
                status: .active,
                startDate: Date(),
                endDate: nil,
                price: 29.99
            )
        ] : [],
        enrollments: []
    )
}

private func makeCourse(title: String, paid: Bool) -> Course {
    Course(
        id: UUID(),
        title: title,
        subtitle: nil,
        description: "Course description",
        thumbnailURL: "https://example.com/thumbnail.jpg",
        coverURL: nil,
        durationSeconds: 1800,
        price: paid ? 49.0 : nil,
        isEnrolled: false,
        isOwned: false,
        isUnlockedBySubscription: false,
        rating: nil,
        reviewCount: 0,
        organizationName: "World Class Scholars",
        level: "Beginner",
        effortDescription: nil,
        spokenLanguages: ["en"],
        modules: [],
        courseReport: nil
    )
}
