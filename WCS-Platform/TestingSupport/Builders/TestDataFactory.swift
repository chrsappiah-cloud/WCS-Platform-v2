//
//  TestDataFactory.swift
//  WCS-Platform
//

import Foundation

enum TestDataFactory {
    static func makeLearner(
        email: String = "learner@wcs.test",
        isPremium: Bool = false,
        role: UserRole = .learner
    ) -> User {
        let orgId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")
        return User(
            id: UUID(),
            email: email,
            name: role == .learner ? "WCS Learner" : "WCS Team Member",
            photoURL: nil,
            role: role,
            activeOrganizationId: orgId,
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

    static func makeCourse(
        title: String = "Test Course",
        paid: Bool = false
    ) -> Course {
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
}
