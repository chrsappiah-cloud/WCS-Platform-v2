import Foundation
import Testing
@testable import WCS_Platform

struct NetworkClientOfflineTests {
    @Test func fetchSubscriptionPlans_inMockMode_returnsIndividualPlans() async throws {
        let client = NetworkClient.shared
        let previousMocks = client.useMocks
        let previousRole = UserDefaults.standard.string(forKey: "wcs.mockRole")
        defer {
            client.useMocks = previousMocks
            if let previousRole {
                UserDefaults.standard.set(previousRole, forKey: "wcs.mockRole")
            } else {
                UserDefaults.standard.removeObject(forKey: "wcs.mockRole")
            }
        }
        client.useMocks = true
        UserDefaults.standard.set(UserRole.learner.rawValue, forKey: "wcs.mockRole")

        let plans = try await client.fetchSubscriptionPlans()
        #expect(!plans.isEmpty)
        #expect(plans.contains(where: { $0.segment == .individual }))
    }

    @Test func fetchCourse_whenMissing_returnsNotFound() async {
        let client = NetworkClient.shared
        let previousMocks = client.useMocks
        defer { client.useMocks = previousMocks }
        client.useMocks = true

        await #expect(throws: Error.self) {
            _ = try await client.fetchCourse(UUID())
        }
    }
}
