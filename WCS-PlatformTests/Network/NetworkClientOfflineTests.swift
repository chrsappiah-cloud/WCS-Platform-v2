import Foundation
import Testing
@testable import WCS_Platform

struct NetworkClientOfflineTests {
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
