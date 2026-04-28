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
        guard let url = URL(string: trimmed), url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else {
            return "Playback URL must be a valid https:// URL."
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

