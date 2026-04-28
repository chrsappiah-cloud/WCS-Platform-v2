//
//  AVFoundationLessonComposer.swift
//  WCS-Platform
//
//  Native Apple composition layer for lesson videos (hybrid + image-sequence paths).
//

import AVFoundation
import Foundation

enum LessonVideoCompositionError: LocalizedError {
    case missingVideoTrack(URL)
    case exportSessionCreationFailed
    case exportFailed(Error?)

    var errorDescription: String? {
        switch self {
        case .missingVideoTrack(let url):
            return "No video track found for clip: \(url.absoluteString)"
        case .exportSessionCreationFailed:
            return "Could not create AVAssetExportSession."
        case .exportFailed(let error):
            return "Local composition failed: \(error?.localizedDescription ?? "unknown error")"
        }
    }
}

struct AVFoundationLessonComposer {
    /// Composes clips sequentially into one local MP4.
    func composeLesson(clips: [URL]) async throws -> URL {
        let validClips = clips.filter { LessonVideoPlaybackPolicy.isNativeAVPlayerHTTPSURL($0) || $0.isFileURL }
        guard !validClips.isEmpty else {
            throw LessonVideoCompositionError.exportFailed(nil)
        }

        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw LessonVideoCompositionError.exportSessionCreationFailed
        }

        var current = CMTime.zero
        for clip in validClips {
            let asset = AVURLAsset(url: clip)
            let duration = try await asset.load(.duration)
            guard let sourceTrack = try await asset.loadTracks(withMediaType: .video).first else {
                throw LessonVideoCompositionError.missingVideoTrack(clip)
            }
            try track.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: sourceTrack,
                at: current
            )
            current = CMTimeAdd(current, duration)
        }

        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("wcs-local-compose-\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        try? FileManager.default.removeItem(at: out)

        guard let exporter = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw LessonVideoCompositionError.exportSessionCreationFailed
        }
        do {
            try await exporter.export(to: out, as: .mp4)
        } catch {
            throw LessonVideoCompositionError.exportFailed(error)
        }
        return out
    }
}

