//
//  AppLaunchConfiguration.swift
//  WCS-Platform
//

import Foundation

struct AppLaunchConfiguration {
    let isUITestMode: Bool
    let mockNetworkMode: String?
    let mockPermissionsMode: String?
    let seedEmptyDatabase: Bool
    let seedExpiredToken: Bool
    let seedMigratedState: Bool

    static func fromCurrentProcess() -> AppLaunchConfiguration {
        let arguments = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment

        return AppLaunchConfiguration(
            isUITestMode: arguments.contains("-uiTestMode"),
            mockNetworkMode: value(after: "-mockNetwork", in: arguments),
            mockPermissionsMode: value(after: "-mockPermissions", in: arguments),
            seedEmptyDatabase: arguments.contains("-seedEmptyDatabase"),
            seedExpiredToken: arguments.contains("-seedExpiredToken"),
            seedMigratedState: arguments.contains("-seedMigratedState")
                || environment["WCS_UI_SEED_MIGRATED_STATE"] == "1"
        )
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else { return nil }
        let value = arguments[valueIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.hasPrefix("-") else { return nil }
        return value
    }
}
