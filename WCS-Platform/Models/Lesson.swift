//
//  Lesson.swift
//  WCS-Platform
//

import Foundation

/// Sidecar WebVTT caption track (`https://…/en.vtt`, or `embedded:wcs-demo-en` for bundled demo text).
struct LessonCaptionTrack: Codable, Hashable, Identifiable, Sendable {
    let language: String
    let label: String
    let webvttURL: String

    var id: String { "\(language)|\(webvttURL)" }
}

struct Lesson: Identifiable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String?
    let type: LessonType
    let videoURL: String?
    let durationSeconds: Int
    let isCompleted: Bool
    let isAvailable: Bool
    let isUnlocked: Bool
    let reading: ReadingContent?
    let quiz: Quiz?
    let assignment: Assignment?
    /// Investor / LMS path: out-of-band WebVTT URLs (parsed in-app, overlaid on `VideoPlayer`).
    let captionTracks: [LessonCaptionTrack]
    /// Server-hydrated resume position (seconds). Merged with local `UserDefaults` in the lesson player.
    let serverResumePositionSeconds: Double?

    init(
        id: UUID,
        title: String,
        subtitle: String?,
        type: LessonType,
        videoURL: String?,
        durationSeconds: Int,
        isCompleted: Bool,
        isAvailable: Bool,
        isUnlocked: Bool,
        reading: ReadingContent?,
        quiz: Quiz?,
        assignment: Assignment?,
        captionTracks: [LessonCaptionTrack] = [],
        serverResumePositionSeconds: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.type = type
        self.videoURL = videoURL
        self.durationSeconds = durationSeconds
        self.isCompleted = isCompleted
        self.isAvailable = isAvailable
        self.isUnlocked = isUnlocked
        self.reading = reading
        self.quiz = quiz
        self.assignment = assignment
        self.captionTracks = captionTracks
        self.serverResumePositionSeconds = serverResumePositionSeconds
    }
}

extension Lesson: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, title, subtitle, type, videoURL, durationSeconds, isCompleted, isAvailable, isUnlocked
        case reading, quiz, assignment, captionTracks, serverResumePositionSeconds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle)
        type = try c.decode(LessonType.self, forKey: .type)
        videoURL = try c.decodeIfPresent(String.self, forKey: .videoURL)
        durationSeconds = try c.decode(Int.self, forKey: .durationSeconds)
        isCompleted = try c.decode(Bool.self, forKey: .isCompleted)
        isAvailable = try c.decode(Bool.self, forKey: .isAvailable)
        isUnlocked = try c.decode(Bool.self, forKey: .isUnlocked)
        reading = try c.decodeIfPresent(ReadingContent.self, forKey: .reading)
        quiz = try c.decodeIfPresent(Quiz.self, forKey: .quiz)
        assignment = try c.decodeIfPresent(Assignment.self, forKey: .assignment)
        captionTracks = try c.decodeIfPresent([LessonCaptionTrack].self, forKey: .captionTracks) ?? []
        serverResumePositionSeconds = try c.decodeIfPresent(Double.self, forKey: .serverResumePositionSeconds)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(subtitle, forKey: .subtitle)
        try c.encode(type, forKey: .type)
        try c.encodeIfPresent(videoURL, forKey: .videoURL)
        try c.encode(durationSeconds, forKey: .durationSeconds)
        try c.encode(isCompleted, forKey: .isCompleted)
        try c.encode(isAvailable, forKey: .isAvailable)
        try c.encode(isUnlocked, forKey: .isUnlocked)
        try c.encodeIfPresent(reading, forKey: .reading)
        try c.encodeIfPresent(quiz, forKey: .quiz)
        try c.encodeIfPresent(assignment, forKey: .assignment)
        if !captionTracks.isEmpty {
            try c.encode(captionTracks, forKey: .captionTracks)
        }
        try c.encodeIfPresent(serverResumePositionSeconds, forKey: .serverResumePositionSeconds)
    }
}

enum LessonType: String, Codable, Hashable {
    case video
    case reading
    case quiz
    case assignment
}

struct ReadingContent: Codable, Hashable {
    let markdown: String
}
