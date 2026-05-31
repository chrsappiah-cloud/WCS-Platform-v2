//
//  WCSBackendStackSettings.swift
//  WCS-Platform
//
//  Primary Supabase backend with Cloudflare R2 + iCloud continuity as backups.
//

import Foundation

nonisolated enum WCSBackendStackSettings {
    private static let supabaseProjectURLKey = "WCSSupabaseProjectURL"
    private static let cloudflareR2PublicBaseKey = "WCSCloudflareR2PublicBaseURL"
    private static let iCloudSyncEnabledKey = "WCSiCloudKitSyncEnabled"
    private static let activateLiveStackKey = "WCSActivateSupabaseBackendStack"

    /// Documented dev project ref (public HTTPS only — no secrets).
    static let defaultSupabaseProjectURL = URL(string: "https://qbmheroqblpcbuqwnzlp.supabase.co")!

    static var supabaseProjectURL: URL {
        if let configured = url(forInfoDictionaryKey: supabaseProjectURLKey) {
            return configured
        }
        if let derived = LessonVideoGenerationSettings.remoteTextToVideoEndpointURL?
            .deletingLastPathComponent()
            .deletingLastPathComponent() {
            return derived
        }
        return defaultSupabaseProjectURL
    }

    static var cloudflareR2PublicBaseURL: URL? {
        url(forInfoDictionaryKey: cloudflareR2PublicBaseKey)
    }

    static var isiCloudSyncEnabled: Bool {
        if let n = Bundle.main.object(forInfoDictionaryKey: iCloudSyncEnabledKey) as? NSNumber {
            return n.boolValue
        }
        if let s = string(forInfoDictionaryKey: iCloudSyncEnabledKey) {
            return (s as NSString).boolValue
        }
        return true
    }

    /// Live Supabase + backup probes (not mock catalog).
    static var shouldActivateLiveBackendStack: Bool {
        if ProcessInfo.processInfo.environment[activateLiveStackKey] == "1" {
            return true
        }
        if ProcessInfo.processInfo.arguments.contains("-activateSupabaseBackend") {
            return true
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestMode") {
            return ProcessInfo.processInfo.environment["WCS_E2E_ACTIVATE_BACKEND"] == "1"
        }
        #endif
        return AppEnvironment.backendProvider == .supabase
    }

    static var textToVideoEdgeURL: URL {
        supabaseProjectURL
            .appendingPathComponent("functions/v1/wcs-lesson-text-to-video")
    }

    static var lessonVideoJobsEdgeURL: URL {
        supabaseProjectURL
            .appendingPathComponent("functions/v1/wcs-lesson-video-jobs")
    }

    static var postgRESTURL: URL {
        supabaseProjectURL.appendingPathComponent("rest/v1/")
    }

    private static func string(forInfoDictionaryKey key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func url(forInfoDictionaryKey key: String) -> URL? {
        guard let raw = string(forInfoDictionaryKey: key), let url = URL(string: raw) else { return nil }
        return url
    }
}
