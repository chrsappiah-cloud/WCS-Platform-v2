//
//  LessonVideoPlaybackPolicy.swift
//  WCS-Platform
//
//  Udemy-style lesson video contracts: HLS detection, YouTube embed routing,
//  playback-rate ladder, and local resume keys (until BFF watch-progress exists).
//

import CoreGraphics
import Foundation

enum LessonVideoPlaybackPolicy: Sendable {
    /// Matches common LMS / Udemy-style speed chips.
    static let udemyStylePlaybackRates: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]

    static func nearestPlaybackRate(to rate: Float) -> Float {
        udemyStylePlaybackRates.min(by: { abs($0 - rate) < abs($1 - rate) }) ?? 1.0
    }

    static func isHLSStreamURL(_ url: URL) -> Bool {
        let s = url.absoluteString.lowercased()
        if s.contains(".m3u8") { return true }
        let path = url.path.lowercased()
        return path.contains("master.m3u8") || path.contains("playlist.m3u8") || path.hasSuffix(".m3u8")
    }

    /// True for `https` URLs that should load in **AVPlayer** (progressive MP4, HLS, Supabase signed URLs, etc.), excluding YouTube (embed path).
    static func isNativeAVPlayerHTTPSURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https" else { return false }
        return youTubeVideoID(from: url) == nil
    }

    static func resumeStorageKey(courseId: UUID, lessonId: UUID) -> String {
        "wcs.lessonVideo.resume.\(courseId.uuidString).\(lessonId.uuidString)"
    }

    static func youTubeVideoID(from url: URL) -> String? {
        let host = (url.host ?? "").lowercased()
        if host.contains("youtu.be") {
            let id = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return id.count == 11 ? id : nil
        }
        guard host.contains("youtube.com") else { return nil }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        if let id = components.queryItems?.first(where: { $0.name == "v" })?.value, id.count == 11 {
            return id
        }
        let path = components.path.lowercased()
        if path.contains("/embed/"), let last = components.path.split(separator: "/").last {
            let id = String(last)
            return id.count == 11 ? id : nil
        }
        return nil
    }
}

/// Manual HLS quality ceiling (ABR still runs under the cap — Udemy-style “quality” menu).
enum HLSQualityPreset: String, CaseIterable, Sendable, Identifiable {
    case auto
    case max1080
    case max720
    case max540
    case max360

    var id: String { rawValue }

    var menuLabel: String {
        switch self {
        case .auto: return "Auto (ABR)"
        case .max1080: return "Up to 1080p"
        case .max720: return "Up to 720p"
        case .max540: return "Up to 540p"
        case .max360: return "Up to 360p"
        }
    }

    /// `CGSize.zero` means no manual cap (player chooses variants freely).
    var preferredMaximumResolution: CGSize {
        switch self {
        case .auto: return .zero
        case .max1080: return CGSize(width: 1920, height: 1080)
        case .max720: return CGSize(width: 1280, height: 720)
        case .max540: return CGSize(width: 960, height: 540)
        case .max360: return CGSize(width: 640, height: 360)
        }
    }
}
