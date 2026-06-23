//
//  LessonVideoSafetyPolicy.swift
//  WCS-Platform
//
//  Production safety checks for lesson playback URLs before publish/compose.
//

import Foundation

enum LessonVideoSafetyPolicy {
    private static let builtInAllowedHosts: Set<String> = [
        "storage.googleapis.com",
        "devstreaming-cdn.apple.com",
        "youtube.com",
        "www.youtube.com",
        "youtu.be",
    ]
    private static let publicUnsignedHosts: Set<String> = [
        "storage.googleapis.com",
        "devstreaming-cdn.apple.com",
    ]

    static var allowedHosts: Set<String> {
        builtInAllowedHosts.union(LessonVideoGenerationSettings.allowedPlaybackHosts)
    }

    static func validatePlaybackURLString(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.isFileURL {
            return nil
        }
        guard let url = URL(string: trimmed), url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else {
            return "Playback URL must be a valid https:// URL or app-owned local video file."
        }
        guard allowedHosts.contains(host) else {
            return "Host \(host) is not allowlisted for lesson playback."
        }
        if LessonVideoPlaybackPolicy.youTubeVideoID(from: url) != nil {
            return nil
        }
        if LessonVideoGenerationSettings.requireSignedPlaybackURLs,
           !publicUnsignedHosts.contains(host),
           !hasSignedQuery(url) {
            return "Playback URL must include a signed query (token/signature/expires)."
        }
        return nil
    }

    static func validateGeneratedLessonVideoURL(_ url: URL) -> String? {
        if url.isFileURL {
            return nil
        }
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else {
            return "Generated lesson video must be a local file or a valid https:// URL."
        }
        if LessonVideoPlaybackPolicy.youTubeVideoID(from: url) != nil || host.contains("youtube") {
            return "Generated lesson video cannot be a YouTube page or companion link."
        }
        if host == "storage.googleapis.com",
           url.path.lowercased().contains("/gtv-videos-bucket/sample/") {
            return "Generated lesson video cannot use public sample video fixtures."
        }
        if host == "devstreaming-cdn.apple.com",
           url.path.lowercased().contains("/streaming/examples/") {
            return "Generated lesson video cannot use Apple sample streaming fixtures."
        }
        if LessonVideoGenerationSettings.requireSignedPlaybackURLs,
           !hasSignedQuery(url) {
            return "Generated lesson video must use a signed playback URL or local Apple-rendered file."
        }
        return nil
    }

    private static func hasSignedQuery(_ url: URL) -> Bool {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return false }
        let names = Set(items.map { $0.name.lowercased() })
        let accepted: [Set<String>] = [
            ["token"],
            ["signature"],
            ["sig"],
            ["x-amz-signature"],
            ["expires", "signature"],
            ["expires", "token"],
        ]
        return accepted.contains { $0.isSubset(of: names) }
    }
}
