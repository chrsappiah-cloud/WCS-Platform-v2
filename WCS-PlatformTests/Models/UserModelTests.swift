import Foundation
import Testing
@testable import WCS_Platform

struct UserModelTests {
    @Test func init_setsRequiredFields() {
        let user = TestFixtures.makeUser(role: .learner)
        #expect(!user.email.isEmpty)
        #expect(!user.name.isEmpty)
        #expect(user.role == .learner)
    }

    @Test func equality_detectsDuplicateUsers() {
        let id = UUID()
        let left = User(
            id: id,
            email: "a@wcs.test",
            name: "A",
            photoURL: nil,
            role: .learner,
            activeOrganizationId: nil,
            memberships: [],
            subscriptions: [],
            enrollments: []
        )
        let right = User(
            id: id,
            email: "a@wcs.test",
            name: "A",
            photoURL: nil,
            role: .learner,
            activeOrganizationId: nil,
            memberships: [],
            subscriptions: [],
            enrollments: []
        )
        #expect(left == right)
    }

    @Test func decode_appliesDefaultsForOptionalCollections() throws {
        let json = """
        {"id":"\(UUID().uuidString)","email":"x@wcs.test","name":"X"}
        """
        let user = try JSONDecoder().decode(User.self, from: Data(json.utf8))
        #expect(user.role == .learner)
        #expect(user.memberships.isEmpty)
        #expect(user.subscriptions.isEmpty)
        #expect(user.enrollments.isEmpty)
    }

    @Test func encodeRoundTrip_preservesIdentity() throws {
        let original = TestFixtures.makeUser(
            role: .orgAdmin,
            subscriptions: [TestFixtures.makeSubscription()]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(User.self, from: data)
        #expect(decoded == original)
    }

    @Test func isPremium_whenActiveSubscriptionExists() {
        let user = TestFixtures.makeUser(subscriptions: [TestFixtures.makeSubscription(status: .active)])
        #expect(user.isPremium)
    }

    @Test func isPremium_falseWhenNoActiveSubscription() {
        let user = TestFixtures.makeUser(subscriptions: [TestFixtures.makeSubscription(status: .canceled)])
        #expect(!user.isPremium)
    }

    @Test func isAdmin_forOrgAdminAndAdminRoles() {
        #expect(TestFixtures.makeUser(role: .orgAdmin).isAdmin)
        #expect(TestFixtures.makeUser(role: .admin).isAdmin)
        #expect(!TestFixtures.makeUser(role: .learner).isAdmin)
    }
}
