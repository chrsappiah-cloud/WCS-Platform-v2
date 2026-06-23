import Foundation
import Testing
@testable import WCS_Platform

@Suite(.serialized)
struct AuthTokenPersistenceTests {
    private let tokenKey = "wcs.authToken"

    @Test func logIn_persistsMockTokenInUserDefaults() async throws {
        let previous = UserDefaults.standard.string(forKey: tokenKey)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: tokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: tokenKey)
            }
        }
        UserDefaults.standard.removeObject(forKey: tokenKey)

        let client = NetworkClient.shared
        let previousMocks = client.useMocks
        client.useMocks = true
        defer { client.useMocks = previousMocks }

        _ = try await client.logIn(email: "learner@wcs.test", password: "secret")

        let token = UserDefaults.standard.string(forKey: tokenKey) ?? ""
        #expect(!token.isEmpty)
        #expect(token.hasPrefix("mock-token"))
    }

    @Test func logIn_withEmptyCredentials_throwsBeforeTokenWrite() async {
        let previous = UserDefaults.standard.string(forKey: tokenKey)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: tokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: tokenKey)
            }
        }
        UserDefaults.standard.set("existing-token", forKey: tokenKey)

        let client = NetworkClient.shared
        let previousMocks = client.useMocks
        client.useMocks = true
        defer { client.useMocks = previousMocks }

        await #expect(throws: Error.self) {
            _ = try await client.logIn(email: "   ", password: "")
        }
        #expect(UserDefaults.standard.string(forKey: tokenKey) == "existing-token")
    }
}
