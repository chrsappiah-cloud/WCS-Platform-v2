//
//  LessonVideoGenerationSettings.swift
//  WCS-Platform
//
//  Single source of truth for admin lesson video generation (mock samples, YouTube Data API companions,
//  and optional HTTPS BFF text-to-video). See `VideoGeneration-InfoPlistKeys.txt` for key names and defaults.
//

import Foundation

nonisolated enum LessonVideoGenerationSettings {

    // MARK: Info.plist keys (keep in sync with VideoGeneration-InfoPlistKeys.txt)

    private static let textToVideoEndpointKey = "WCSLessonTextToVideoEndpoint"
    private static let textToVideoBearerKey = "WCSLessonTextToVideoAPIKey"
    private static let textToVideoSupabaseAnonKey = "WCSLessonTextToVideoSupabaseAnonKey"
    private static let textToVideoTimeoutSecondsKey = "WCSLessonTextToVideoRequestTimeoutSeconds"
    private static let providerBackendHintKey = "WCSLessonTextToVideoProviderBackendHint"
    private static let mockDelayMillisKey = "WCSLessonVideoMockGenerationDelayMillis"
    private static let textToVideoExtraHTTPHeadersJSONKey = "WCSLessonTextToVideoExtraHTTPHeadersJSON"
    private static let lessonVideoJobListSecretKey = "WCSLessonVideoJobListSecret"

    // MARK: Remote text-to-video (BFF / Supabase Edge)

    /// Full `https://…` URL for `POST` lesson generation (JSON in / JSON `playbackURL` out). Empty / invalid → remote disabled.
    static var remoteTextToVideoEndpointURL: URL? {
        guard let trimmed = string(forInfoPlistKey: textToVideoEndpointKey),
              let url = URL(string: trimmed),
              url.scheme?.lowercased() == "https" else {
            return nil
        }
        return url
    }

    /// Optional `Authorization: Bearer …` for the text-to-video endpoint (function secret or user JWT).
    static var remoteTextToVideoBearerToken: String? {
        nonEmptyString(forInfoPlistKey: textToVideoBearerKey)
    }

    /// Optional `apikey` header (and fallback `Authorization: Bearer` when `WCSLessonTextToVideoAPIKey` is empty) for Supabase Edge Functions.
    static var remoteTextToVideoSupabaseAnonKey: String? {
        nonEmptyString(forInfoPlistKey: textToVideoSupabaseAnonKey)
    }

    /// Per-request timeout for the text-to-video `POST`. Default 120s; clamp 10…600.
    static var remoteTextToVideoRequestTimeoutSeconds: TimeInterval {
        let raw = double(forInfoPlistKey: textToVideoTimeoutSecondsKey) ?? 120
        return min(600, max(10, raw))
    }

    /// Opaque hint for your BFF (e.g. `sora`, `luma`, `ltx`, `svd-self-hosted`) — forwarded as `providerBackendHint` in JSON.
    static var providerBackendHint: String? {
        nonEmptyString(forInfoPlistKey: providerBackendHintKey)
    }

    /// Optional JSON object of extra headers, e.g. `{"X-Custom-Auth":"value"}`. Keys/values must be strings.
    static var remoteTextToVideoExtraHTTPHeaders: [String: String] {
        guard let raw = nonEmptyString(forInfoPlistKey: textToVideoExtraHTTPHeadersJSONKey),
              let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        var out: [String: String] = [:]
        for (k, v) in obj {
            if let s = v as? String { out[k] = s }
            else if let n = v as? NSNumber { out[k] = n.stringValue }
        }
        return out
    }

    static func makeURLSessionForTextToVideo() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        let t = remoteTextToVideoRequestTimeoutSeconds
        config.timeoutIntervalForRequest = t
        config.timeoutIntervalForResource = t + 120
        config.waitsForConnectivity = true
        config.httpAdditionalHeaders = ["Accept": "application/json"]
        return URLSession(configuration: config)
    }

    // MARK: Mock / simulated pipeline

    /// Delay before each “generated” asset appears in admin UI when using mock or after remote fallback. Default 600ms.
    static var mockGenerationDelayNanoseconds: UInt64 {
        let ms = double(forInfoPlistKey: mockDelayMillisKey) ?? 600
        let clamped = min(30_000, max(0, ms))
        return UInt64(clamped * 1_000_000)
    }

    /// `true` when remote text-to-video should run (endpoint configured).
    static var isRemoteTextToVideoEnabled: Bool {
        remoteTextToVideoEndpointURL != nil
    }

    /// Shared secret for `GET …/wcs-lesson-video-jobs` (must match Edge secret `WCS_JOB_LIST_SECRET`).
    static var lessonVideoJobListSecret: String? {
        nonEmptyString(forInfoPlistKey: lessonVideoJobListSecretKey)
    }

    /// Derived from `WCSLessonTextToVideoEndpoint` by swapping the last path segment to `wcs-lesson-video-jobs`.
    static var remoteLessonVideoJobHistoryGETURL: URL? {
        guard let base = remoteTextToVideoEndpointURL else { return nil }
        let s = base.absoluteString
        guard let range = s.range(of: "wcs-lesson-text-to-video") else { return nil }
        return URL(string: s.replacingCharacters(in: range, with: "wcs-lesson-video-jobs"))
    }

    /// `true` when admin can load the render-job audit list from Edge.
    static var isLessonVideoJobHistoryEnabled: Bool {
        remoteLessonVideoJobHistoryGETURL != nil && lessonVideoJobListSecret != nil
    }

    // MARK: Plist helpers

    private static func string(forInfoPlistKey key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func nonEmptyString(forInfoPlistKey key: String) -> String? {
        string(forInfoPlistKey: key)
    }

    private static func double(forInfoPlistKey key: String) -> Double? {
        if let n = Bundle.main.object(forInfoDictionaryKey: key) as? NSNumber {
            return n.doubleValue
        }
        if let s = string(forInfoPlistKey: key), let v = Double(s) {
            return v
        }
        return nil
    }
}
