import Foundation
import Testing
@testable import WCS_Platform

struct AppLaunchConfigurationTests {
    @Test
    func parsesExpectedReviewHarnessFlags() {
        let args = [
            "WCS-Platform",
            "-uiTestMode",
            "-mockNetwork", "offline",
            "-mockPermissions", "deniedCamera",
            "-mockStoreKit", "productsFailure",
            "-seedEmptyDatabase",
            "-seedExpiredToken"
        ]

        let config = LocalLaunchConfiguration(
            isUITestMode: args.contains("-uiTestMode"),
            mockNetworkMode: "offline",
            mockPermissionsMode: "deniedCamera",
            mockStoreKitMode: "productsFailure",
            seedEmptyDatabase: args.contains("-seedEmptyDatabase"),
            seedExpiredToken: args.contains("-seedExpiredToken"),
            seedMigratedState: false
        )

        #expect(config.isUITestMode)
        #expect(config.mockNetworkMode == "offline")
        #expect(config.mockPermissionsMode == "deniedCamera")
        #expect(config.mockStoreKitMode == "productsFailure")
        #expect(config.seedEmptyDatabase)
        #expect(config.seedExpiredToken)
        #expect(!config.seedMigratedState)
    }
}

private struct LocalLaunchConfiguration {
    let isUITestMode: Bool
    let mockNetworkMode: String?
    let mockPermissionsMode: String?
    let mockStoreKitMode: String?
    let seedEmptyDatabase: Bool
    let seedExpiredToken: Bool
    let seedMigratedState: Bool
}
