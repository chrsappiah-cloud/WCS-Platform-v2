import Foundation
@testable import WCS_Platform

enum TestFixtures {
    static let organizationId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    static func makeSubscription(
        status: SubscriptionStatus = .active,
        planId: String = "premium-monthly"
    ) -> Subscription {
        Subscription(
            id: UUID(),
            planId: planId,
            planName: "Premium Membership",
            status: status,
            startDate: Date(),
            endDate: nil,
            price: 29.99
        )
    }

    static func makeUser(
        role: UserRole = .learner,
        enrollments: [Enrollment] = []
    ) -> User {
        User(
            id: UUID(),
            email: "learner@wcs.test",
            name: "WCS Learner",
            photoURL: nil,
            role: role,
            activeOrganizationId: organizationId,
            memberships: [],
            enrollments: enrollments
        )
    }

    static func makeCourse(
        title: String = "Test Course",
        modules: [Module] = []
    ) -> Course {
        Course(
            id: UUID(),
            title: title,
            subtitle: nil,
            description: "Description",
            thumbnailURL: "https://example.com/t.jpg",
            coverURL: nil,
            durationSeconds: 1200,
            isEnrolled: false,
            isOwned: false,
            rating: 4.5,
            reviewCount: 10,
            organizationName: "World Class Scholars",
            level: "Beginner",
            effortDescription: nil,
            spokenLanguages: ["en"],
            modules: modules
        )
    }
}
