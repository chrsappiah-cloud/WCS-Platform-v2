//
//  WebVTTParser.swift
//  WCS-Platform
//
//  Minimal WebVTT cue parser for sidecar `.vtt` files (investor / learner validation).
//

import Foundation

struct WebVTTCue: Sendable, Equatable {
    let startSeconds: Double
    let endSeconds: Double
    let text: String
}

enum WebVTTParser: Sendable {
    /// Parses a WebVTT document into cues (best-effort; ignores NOTE / STYLE regions).
    static func parseCues(from webvtt: String) -> [WebVTTCue] {
        var cues: [WebVTTCue] = []
        let lines = webvtt.split(whereSeparator: \.isNewline).map(String.init)
        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line == "WEBVTT" || line.hasPrefix("WEBVTT ") {
                i += 1
                continue
            }
            if line.isEmpty || line.hasPrefix("NOTE") || line == "STYLE" {
                i += 1
                continue
            }
            // Optional cue identifier line (non-timing).
            var timingLine = line
            if !timingLine.contains("-->") {
                i += 1
                if i >= lines.count { break }
                timingLine = lines[i].trimmingCharacters(in: .whitespaces)
            }
            guard let range = parseTimingLine(timingLine) else {
                i += 1
                continue
            }
            i += 1
            var textLines: [String] = []
            while i < lines.count {
                let t = lines[i]
                if t.trimmingCharacters(in: .whitespaces).isEmpty { break }
                textLines.append(t)
                i += 1
            }
            let body = textLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !body.isEmpty {
                cues.append(WebVTTCue(startSeconds: range.start, endSeconds: range.end, text: body))
            }
            i += 1
        }
        return cues
    }

    static func activeCue(for timeSeconds: Double, in cues: [WebVTTCue]) -> String? {
        cues.first { timeSeconds >= $0.startSeconds && timeSeconds < $0.endSeconds }?.text
    }

    private static func parseTimingLine(_ line: String) -> (start: Double, end: Double)? {
        let parts = line.components(separatedBy: "-->")
        guard parts.count == 2 else { return nil }
        guard let start = parseTimestamp(parts[0].trimmingCharacters(in: .whitespaces)),
              let end = parseTimestamp(parts[1].trimmingCharacters(in: .whitespaces))
        else { return nil }
        return (start, end)
    }

    /// Supports `HH:MM:SS.mmm`, `MM:SS.mmm`, and `HH:MM:SS` (WebVTT subset).
    private static func parseTimestamp(_ raw: String) -> Double? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        let comps = s.split(separator: ":").map(String.init)
        guard !comps.isEmpty else { return nil }
        if comps.count == 3,
           let h = Double(comps[0]),
           let m = Double(comps[1]),
           let sec = parseSecondsFragment(comps[2]) {
            return h * 3600 + m * 60 + sec
        }
        if comps.count == 2,
           let m = Double(comps[0]),
           let sec = parseSecondsFragment(comps[1]) {
            return m * 60 + sec
        }
        return nil
    }

    private static func parseSecondsFragment(_ part: String) -> Double? {
        let p = part.replacingOccurrences(of: ",", with: ".")
        return Double(p)
    }
}

// MARK: - Investor / offline demo (no CDN required)

enum InvestorDemoEmbeddedCaptions: Sendable {
    static let englishDocument: String = """
    WEBVTT

    00:00:00.000 --> 00:00:05.000
    WCS learner experience — captions validate inclusive design.

    00:00:05.000 --> 00:00:14.000
    Investor view: WebVTT sidecar, HLS quality caps, and server-backed watch progress.
    """
}
