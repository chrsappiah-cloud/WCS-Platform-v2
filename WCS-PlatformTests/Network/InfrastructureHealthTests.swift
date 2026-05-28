import Foundation
import Testing
@testable import WCS_Platform

struct InfrastructureHealthTests {
    @Test
    func storageBackendsStatus_includesCloudflareAndiCloudCapabilities() async throws {
        let previousRole = UserDefaults.standard.string(forKey: "wcs.mockRole")
        let client = NetworkClient.shared
        let previousMocks = client.useMocks
        defer {
            client.useMocks = previousMocks
            if let previousRole {
                UserDefaults.standard.set(previousRole, forKey: "wcs.mockRole")
            } else {
                UserDefaults.standard.removeObject(forKey: "wcs.mockRole")
            }
        }

        client.useMocks = true
        UserDefaults.standard.set(UserRole.orgAdmin.rawValue, forKey: "wcs.mockRole")

        let status = try await client.fetchStorageBackendsStatus()
        let providers = Set(status.providers.map(\.provider))
        #expect(providers.contains(.cloudflare))
        #expect(providers.contains(.iCloud))
        #expect(status.failoverEnabled)
    }

    @Test
    func generationCapabilityCheck_reportsExternalAndAppleEcosystemSurfaces() async {
        let previousRole = UserDefaults.standard.string(forKey: "wcs.mockRole")
        let client = NetworkClient.shared
        let previousMocks = client.useMocks
        defer {
            client.useMocks = previousMocks
            if let previousRole {
                UserDefaults.standard.set(previousRole, forKey: "wcs.mockRole")
            } else {
                UserDefaults.standard.removeObject(forKey: "wcs.mockRole")
            }
        }

        client.useMocks = true
        UserDefaults.standard.set(UserRole.orgAdmin.rawValue, forKey: "wcs.mockRole")
        let status = await client.fetchGenerationCapabilityStatus()

        let systems = status.checks.map(\.system)
        #expect(systems.contains(where: { $0.localizedCaseInsensitiveContains("Open Library") }))
        #expect(systems.contains(where: { $0.localizedCaseInsensitiveContains("OpenAlex") }))
        #expect(systems.contains(where: { $0.localizedCaseInsensitiveContains("YouTube Data API") }))
        #expect(systems.contains(where: { $0.localizedCaseInsensitiveContains("Cloud AI Companion") }))
    }
}

