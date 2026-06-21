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
            accessRecords: [],
            enrollments: []
        )
        let right = User(
            id: id,
            email: "a@wcs.test",
            name: "A",
            photoURL: nil,
            role: .learner,
            activeOrganizationId: nil,
            accessRecords: [],
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
        #expect(user.accessRecords.isEmpty)
        #expect(user.enrollments.isEmpty)
    }

    @Test func isAdmin_forOrgAdminAndAdminRoles() {
        #expect(TestFixtures.makeUser(role: .orgAdmin).isAdmin)
        #expect(TestFixtures.makeUser(role: .admin).isAdmin)
        #expect(!TestFixtures.makeUser(role: .learner).isAdmin)
    }
}
