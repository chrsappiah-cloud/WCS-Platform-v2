//
//  ManualExternalLessonVideoModels.swift
//  WCS-Platform
//
//  Tracks externally-produced lesson videos (Mootion, Invideo AI, etc.) for admin workflows.
//  Source is persisted in `AdminLessonDraft.notes` via `LessonManualVideoBackup` machine lines.
//

import Foundation

/// Where the administrator obtained the lesson master (export / render host).
enum ExternalLessonVideoSource: String, Codable, Hashable, CaseIterable, Identifiable {
    case mootion
    case invideo
    case manual
    case other

    var id: String { rawValue }

    /// Stable token written to `wcs.externalVideoSource:` lines.
    var storageToken: String { rawValue }

    var displayLabel: String {
        switch self {
        case .mootion: return "Mootion"
        case .invideo: return "Invideo AI"
        case .manual: return "Manual / other editor"
        case .other: return "Other platform"
        }
    }

    init?(storageToken: String) {
        let t = storageToken.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.init(rawValue: t)
    }
}

/// Lightweight probe of a local video file (security-scoped URL) before upload to your BFF / object store.
struct ManualVideoFileProbe: Sendable, Hashable {
    let fileName: String
    let fileSizeBytes: Int64
    let durationSeconds: Double
    let pixelWidth: Int
    let pixelHeight: Int
    let pathExtension: String
}

enum ManualVideoFileValidationError: LocalizedError, Equatable {
    case fileNotFound
    case fileTooLarge(maxBytes: Int64)
    case invalidFormat(allowed: [String])
    case notReadable
    case avFoundationFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Video file was not found."
        case .fileTooLarge(let max):
            let f = ByteCountFormatter.string(fromByteCount: max, countStyle: .file)
            return "File exceeds the maximum size (\(f))."
        case .invalidFormat(let allowed):
            return "Unsupported format. Allowed: \(allowed.joined(separator: ", "))."
        case .notReadable:
            return "Could not read the file. Try copying it to Files first."
        case .avFoundationFailed(let detail):
            return "Could not read video metadata: \(detail)"
        }
    }
}
