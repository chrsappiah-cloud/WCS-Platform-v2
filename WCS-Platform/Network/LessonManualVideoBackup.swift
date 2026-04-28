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

    static func mergeURLLine(into notes: String, url: String) -> String {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let header = "\(urlLinePrefix) \(trimmedURL)"
        let body = stripMachineLines(from: notes)
        if body.isEmpty { return header }
        return "\(header)\n\n\(body)"
    }

    static func stripMachineLines(from notes: String) -> String {
        notes
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }
            .filter { line in
                let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.lowercased().hasPrefix(urlLinePrefix.lowercased()) { return false }
                if t.lowercased().hasPrefix("manual video backup url:") { return false }
                return true
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
