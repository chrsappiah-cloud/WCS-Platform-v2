//
//  AppEnvironment.swift
//  WCS-Platform
//

import Foundation

enum AppEnvironment {
    private static let infoPlistKey = "WCSPlatformAPIBaseURL"
    private static let backendProviderInfoPlistKey = "WCSBackendProvider"
    private static let adminCodeInfoPlistKey = "WCSAdminAccessCode"
    private static let appleSubscriptionProductIDsInfoPlistKey = "WCSAppleSubscriptionProductIDs"
    private static let debugSafeModeUserDefaultsKey = "wcs.debugSafeMode"

    enum BackendProvider: String {
        case supabase
    }

    /// Locked backend foundation for MVP execution window.
    static var backendProvider: BackendProvider {
        if let raw = Bundle.main.object(forInfoDictionaryKey: backendProviderInfoPlistKey) as? String,
           let provider = BackendProvider(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) {
            return provider
        }
        return .supabase
    }

    /// Base URL for the Nest (or other) platform API, e.g. `http://127.0.0.1:3000` for Simulator against a Mac-hosted API.
    static var platformAPIBaseURL: URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String,
           let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
           !raw.isEmpty {
            return url
        }
        return URL(string: "https://api.wcs.education/v1")!
    }

    /// Admin gate code for AI course generator. Configure via Info.plist key `WCSAdminAccessCode`.
    static var adminAccessCode: String {
        if let raw = Bundle.main.object(forInfoDictionaryKey: adminCodeInfoPlistKey) as? String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return "wcs-admin-2026"
    }

    /// Reduces aggressive UI refresh and keyboard-related churn for Simulator debugging sessions.
    static var debugSafeMode: Bool {
        UserDefaults.standard.bool(forKey: debugSafeModeUserDefaultsKey)
    }

    static func setDebugSafeMode(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: debugSafeModeUserDefaultsKey)
    }

    /// Comma-separated StoreKit product ids from Info.plist key `WCSAppleSubscriptionProductIDs`.
    static var appleSubscriptionProductIDs: Set<String> {
        if let raw = Bundle.main.object(forInfoDictionaryKey: appleSubscriptionProductIDsInfoPlistKey) as? String {
            let ids = raw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !ids.isEmpty { return Set(ids) }
        }
        return []
    }

    /// Extra simulator-only stabilization for noisy keyboard/haptics sessions.
    static var simulatorStabilityMode: Bool {
        #if targetEnvironment(simulator)
        #if DEBUG
        if !UserDefaults.standard.object(forKey: debugSafeModeUserDefaultsKey).isNil {
            return debugSafeMode
        }
        return true
        #else
        return debugSafeMode
        #endif
        #else
        return false
        #endif
    }
}

private extension Optional {
    var isNil: Bool { self == nil }
}
