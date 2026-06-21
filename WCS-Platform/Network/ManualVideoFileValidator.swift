//
//  ManualVideoFileValidator.swift
//  WCS-Platform
//
//  Validates local lesson video files (size, container extension) and probes duration / resolution via AVFoundation.
//

import AVFoundation
import Foundation

enum ManualVideoFileValidator {
    /// Matches common exports from Mootion, Invideo AI, and desktop editors.
    static let allowedExtensions: [String] = ["mp4", "mov", "m4v", "webm"]

    /// Default cap aligned with admin doc (5 GB); tighten per environment if needed.
    static let maxFileSizeBytes: Int64 = 5 * 1024 * 1024 * 1024

    static func validateExtension(of url: URL) throws {
        let ext = url.pathExtension.lowercased()
        guard allowedExtensions.contains(ext) else {
            throw ManualVideoFileValidationError.invalidFormat(allowed: allowedExtensions)
        }
    }

    static func validateFileSize(at url: URL) throws {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        let size = Int64(values.fileSize ?? 0)
        guard size > 0 else {
            throw ManualVideoFileValidationError.fileNotFound
        }
        guard size <= maxFileSizeBytes else {
            throw ManualVideoFileValidationError.fileTooLarge(maxBytes: maxFileSizeBytes)
        }
    }

    /// Call only while holding security-scoped access to `fileURL` when required (e.g. fileImporter picks).
    static func probe(fileURL: URL) async throws -> ManualVideoFileProbe {
        try validateExtension(of: fileURL)
        try validateFileSize(at: fileURL)

        guard FileManager.default.isReadableFile(atPath: fileURL.path) else {
            throw ManualVideoFileValidationError.notReadable
        }

        let asset = AVURLAsset(url: fileURL)
        do {
            let duration = try await asset.load(.duration)
            let seconds = duration.seconds.isFinite ? duration.seconds : 0
            let tracks = try await asset.loadTracks(withMediaType: .video)
            var w = 0
            var h = 0
            if let track = tracks.first {
                let size = try await track.load(.naturalSize)
                w = Int(size.width.rounded())
                h = Int(size.height.rounded())
            }
            let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            let sizeBytes = Int64(values.fileSize ?? 0)
            return ManualVideoFileProbe(
                fileName: fileURL.lastPathComponent,
                fileSizeBytes: sizeBytes,
                durationSeconds: seconds,
                pixelWidth: w,
                pixelHeight: h,
                pathExtension: fileURL.pathExtension.lowercased()
            )
        } catch {
            throw ManualVideoFileValidationError.avFoundationFailed(error.localizedDescription)
        }
    }

    static func importToLocalBackupStorage(fileURL: URL, lessonId: UUID) async throws -> (url: URL, probe: ManualVideoFileProbe) {
        let probe = try await probe(fileURL: fileURL)
        let directory = try localBackupDirectory()
        let safeBaseName = fileURL.deletingPathExtension().lastPathComponent
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let fileName = "\(lessonId.uuidString)-\(safeBaseName.isEmpty ? "lesson-video" : safeBaseName).\(probe.pathExtension)"
        let destination = directory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: fileURL, to: destination)
        return (destination, probe)
    }

    static func localBackupDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("ManualLessonVideoBackups", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
