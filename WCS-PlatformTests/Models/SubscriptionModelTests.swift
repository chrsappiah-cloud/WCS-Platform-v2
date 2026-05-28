import Foundation
import Testing
@testable import WCS_Platform

struct SubscriptionModelTests {
    @Test func init_setsRequiredFields() {
        let sub = TestFixtures.makeSubscription()
        #expect(!sub.planId.isEmpty)
        #expect(!sub.planName.isEmpty)
        #expect(sub.status == .active)
    }

    @Test func equality_requiresMatchingIdentifiers() {
        let id = UUID()
        let left = Subscription(
            id: id,
            planId: "plan-a",
            planName: "Plan A",
            status: .active,
            startDate: Date(timeIntervalSince1970: 1),
            endDate: nil,
            price: 10
        )
        let right = Subscription(
            id: id,
            planId: "plan-a",
            planName: "Plan A",
            status: .active,
            startDate: Date(timeIntervalSince1970: 1),
            endDate: nil,
            price: 10
        )
        #expect(left == right)
        #expect(left != TestFixtures.makeSubscription())
    }

    @Test func decode_parsesStatusFromJSON() throws {
        let json = """
        {"id":"\(UUID().uuidString)","planId":"p1","planName":"Pro","status":"active","startDate":1735689600,"price":29.99}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let sub = try decoder.decode(Subscription.self, from: Data(json.utf8))
        #expect(sub.status == .active)
    }
}
