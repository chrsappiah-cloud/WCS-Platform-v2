//
//  LessonManualVideoBackup.swift
//  WCS-Platform
//
//  Structured HTTPS fallback for lesson videos when AI / BFF generation is unavailable.
//  Stored on `AdminLessonDraft.notes` as a dedicated line: `wcs.manualVideoURL: https://…`
//

import Foundation

enum LessonManualVideoBackup {
    /// First line wins for machine parsing; additional lesson notes follow after blank lines.
    static let urlLinePrefix = "wcs.manualVideoURL:"
    /// Optional provenance for externally-rendered masters (Mootion, Invideo AI, etc.).
    static let externalSourceLinePrefix = "wcs.externalVideoSource:"

    /// Persists HTTPS playback URL and optional external tool provenance; strips prior machine lines first.
    static func mergeManualVideoMachineLines(
        into notes: String,
        httpsURL: String?,
        externalSource: ExternalLessonVideoSource?
    ) -> String {
        let body = stripMachineLines(from: notes)
        var headers: [String] = []
        if let raw = httpsURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
           let validated = validatedHTTPSURL(raw) {
            headers.append("\(urlLinePrefix) \(validated)")
        }
        if let src = externalSource, !headers.isEmpty {
            headers.append("\(externalSourceLinePrefix) \(src.storageToken)")
        }
        if headers.isEmpty { return body }
        let header = headers.joined(separator: "\n")
        if body.isEmpty { return header }
        return "\(header)\n\n\(body)"
    }

    static func mergeURLLine(into notes: String, url: String) -> String {
        mergeManualVideoMachineLines(into: notes, httpsURL: url, externalSource: nil)
    }

    static func stripMachineLines(from notes: String) -> String {
        notes
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }
            .filter { line in
                let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.lowercased().hasPrefix(urlLinePrefix.lowercased()) { return false }
                if t.lowercased().hasPrefix(externalSourceLinePrefix.lowercased()) { return false }
                if t.lowercased().hasPrefix("manual video backup url:") { return false }
                return true
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func extractExternalSource(from notes: String) -> ExternalLessonVideoSource? {
        for raw in notes.components(separatedBy: .newlines) {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard t.lowercased().hasPrefix(externalSourceLinePrefix.lowercased()) else { continue }
            let rest = String(t.dropFirst(externalSourceLinePrefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return ExternalLessonVideoSource(storageToken: rest)
        }
        return nil
    }

    /// Returns a normalized `https` URL string when one is declared in notes.
    static func extractHTTPSURL(from notes: String) -> String? {
        for raw in notes.components(separatedBy: .newlines) {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            if t.lowercased().hasPrefix(urlLinePrefix.lowercased()) {
                let rest = String(t.dropFirst(urlLinePrefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                if let u = validatedHTTPSURL(rest) { return u }
            }
            if t.lowercased().hasPrefix("manual video backup url:") {
                let rest = String(t.dropFirst("Manual video backup URL:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                if let u = validatedHTTPSURL(rest) { return u }
            }
        }
        guard let range = notes.range(of: "https://") else { return nil }
        let tail = String(notes[range.lowerBound...])
        let token = tail.prefix { ch in
            !ch.isWhitespace && ch != "\n" && ch != ")" && ch != "]" && ch != ">"
        }
        return validatedHTTPSURL(String(token))
    }

    static func validatedHTTPSURL(_ raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: s), url.scheme?.lowercased() == "https", url.host != nil else { return nil }
        return url.absoluteString
    }
}
