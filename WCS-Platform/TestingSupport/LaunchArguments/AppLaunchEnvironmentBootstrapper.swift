//
//  AppLaunchEnvironmentBootstrapper.swift
//  WCS-Platform
//

import Foundation

enum AppLaunchEnvironmentBootstrapper {
    static func apply() {
        let config = AppLaunchConfiguration.fromCurrentProcess()
        applyLaunchEnvironmentOverrides()
        applyUITestMode(config.isUITestMode)
        applyNetworkMode(config.mockNetworkMode)
        applyPermissionMode(config.mockPermissionsMode)
        applyStoreKitMode(config.mockStoreKitMode)
        applySeedModes(config)
    }

    private static func applyLaunchEnvironmentOverrides() {
        let environment = ProcessInfo.processInfo.environment
        let isHarnessLaunch = ProcessInfo.processInfo.arguments.contains("-uiTestMode")
            || environment["WCS_MOCK_ROLE"] != nil
            || environment["WCS_UI_TEST_ADMIN_ACCESS_CODE"] != nil
        guard isHarnessLaunch else { return }

        if let adminCode = environment["WCS_UI_TEST_ADMIN_ACCESS_CODE"],
           !adminCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            UserDefaults.standard.set(adminCode, forKey: "wcs.uiTest.adminAccessCode")
        }
        if let role = environment["WCS_MOCK_ROLE"],
           !role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            UserDefaults.standard.set(role, forKey: "wcs.mockRole")
            UserDefaults.standard.set(
                role == UserRole.orgAdmin.rawValue || role == UserRole.admin.rawValue,
                forKey: "wcs.mockAdminMode"
            )
        }
        NetworkClient.shared.useMocks = true
    }

    private static func applyUITestMode(_ enabled: Bool) {
        if enabled {
            NetworkClient.shared.useMocks = true
        }
    }

    private static func applyNetworkMode(_ mode: String?) {
        guard let mode else { return }
        switch mode.lowercased() {
        case "offline":
            NetworkClient.shared.useMocks = true
            UserDefaults.standard.set(false, forKey: "wcs.mockPremiumMode")
        case "online":
            NetworkClient.shared.useMocks = false
        default:
            break
        }
    }

    private static func applyPermissionMode(_ mode: String?) {
        guard let mode else { return }
        if mode.localizedCaseInsensitiveContains("denied") {
            UserDefaults.standard.set(false, forKey: "wcs.mockPremiumMode")
            UserDefaults.standard.set(UserRole.learner.rawValue, forKey: "wcs.mockRole")
        }
    }

    private static func applyStoreKitMode(_ mode: String?) {
        guard let mode else { return }
        if mode.localizedCaseInsensitiveContains("productsFailure") {
            UserDefaults.standard.set("", forKey: "wcs.test.appleSubscriptionProductIDsOverride")
        }
    }

    private static func applySeedModes(_ config: AppLaunchConfiguration) {
        if config.seedEmptyDatabase {
            Task {
                await AdminCourseDraftStore.shared.clearAll()
                await MockLearningStore.shared.resetLearningStateForTests()
            }
        }
        if config.seedExpiredToken {
            UserDefaults.standard.set("expired-token", forKey: "wcs.authToken")
        }
        if config.seedMigratedState {
            UserDefaults.standard.set(true, forKey: "wcs.seedMigratedState")
        }
    }
}
