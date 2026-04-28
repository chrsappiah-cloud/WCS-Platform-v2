//
//  ModuleVideoDiscoveryPipeline.swift
//  WCS-Platform
//
//  Maps course/module/lesson scripts to live YouTube search + embeds (companion to catalog `videoURL` and admin `MockAIVideoGenerator`).
//

import Foundation

/// A lesson line used for external video discovery (catalog `Course` / `Lesson`).
struct LessonVideoScriptLine: Identifiable, Hashable, Sendable {
    let id: UUID
    let courseTitle: String
    let moduleTitle: String
    let lessonTitle: String
    let lessonSubtitle: String?

    var youTubeSearchQuery: String {
        let focus = [lessonTitle, lessonSubtitle].compactMap(\.self).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let joined = focus.joined(separator: " ")
        return "\(courseTitle) \(moduleTitle) \(joined) online course lecture documentary".trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Same pipeline for administrator drafts prior to publish.
struct AdminLessonVideoScriptLine: Identifiable, Hashable, Sendable {
    let id: UUID
    let draftTitle: String
    let moduleTitle: String
    let lessonTitle: String
    let lessonNotes: String

    var youTubeSearchQuery: String {
        let note = lessonNotes.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let cue = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if cue.isEmpty {
            return "\(draftTitle) \(moduleTitle) \(lessonTitle) curriculum walkthrough tutorial"
        }
        return "\(draftTitle) \(moduleTitle) \(lessonTitle) \(cue)"
    }
}

struct LessonVideoDiscoveryResult: Identifiable, Hashable, Sendable {
    let scriptLine: LessonVideoScriptLine
    let snippets: [YouTubeVideoSnippet]

    var id: UUID { scriptLine.id }
}

struct AdminLessonVideoDiscoveryResult: Identifiable, Hashable, Sendable {
    let scriptLine: AdminLessonVideoScriptLine
    let snippets: [YouTubeVideoSnippet]

    var id: UUID { scriptLine.id }
}

enum ModuleVideoDiscoveryPipeline {
    private static let blockedTerms = ["adult", "nsfw", "porn", "gambling", "weapon"]

    /// Builds one script line per **video** lesson in display order.
    static func scriptLines(from course: Course) -> [LessonVideoScriptLine] {
        let sortedModules = course.modules.sorted { $0.order < $1.order }
        var lines: [LessonVideoScriptLine] = []
        for module in sortedModules {
            for lesson in module.lessons where lesson.type == .video {
                lines.append(
                    LessonVideoScriptLine(
                        id: lesson.id,
                        courseTitle: course.title,
                        moduleTitle: module.title,
                        lessonTitle: lesson.title,
                        lessonSubtitle: lesson.subtitle
                    )
                )
            }
        }
        return lines
    }

    static func adminScriptLines(from draft: AdminCourseDraft) -> [AdminLessonVideoScriptLine] {
        var lines: [AdminLessonVideoScriptLine] = []
        for module in draft.modules {
            for lesson in module.lessons where lesson.kind == .video || lesson.kind == .live {
                lines.append(
                    AdminLessonVideoScriptLine(
                        id: lesson.id,
                        draftTitle: draft.title,
                        moduleTitle: module.title,
                        lessonTitle: lesson.title,
                        lessonNotes: lesson.notes
                    )
                )
            }
        }
        return lines
    }

    static func resolveCompanionVideos(
        scriptLines: [LessonVideoScriptLine],
        maxResultsPerLesson: Int = 2,
        configuration: YouTubeSearchConfiguration? = nil,
        session: URLSession? = nil
    ) async throws -> [LessonVideoDiscoveryResult] {
        guard YouTubeSearchAPIClient.resolveAPIKey() != nil else {
            throw YouTubeAPIError.missingAPIKey
        }
        let configuration = configuration ?? .wcsLearning
        var results: [LessonVideoDiscoveryResult] = []
        results.reserveCapacity(scriptLines.count)
        for line in scriptLines {
            let page = try await YouTubeSearchAPIClient.searchVideos(
                query: line.youTubeSearchQuery,
                configuration: configuration,
                maxResults: maxResultsPerLesson,
                session: session
            )
            let filtered = page.items.filter {
                isAllowed(snippet: $0, for: line.youTubeSearchQuery)
            }
            let snippets = snippetsForDisplay(
                relevanceFiltered: filtered,
                pageItems: page.items,
                maxResults: maxResultsPerLesson
            )
            results.append(LessonVideoDiscoveryResult(scriptLine: line, snippets: snippets))
        }
        return results
    }

    static func resolveAdminDraftVideos(
        scriptLines: [AdminLessonVideoScriptLine],
        maxResultsPerLesson: Int = 2,
        configuration: YouTubeSearchConfiguration? = nil,
        session: URLSession? = nil
    ) async throws -> [AdminLessonVideoDiscoveryResult] {
        guard YouTubeSearchAPIClient.resolveAPIKey() != nil else {
            throw YouTubeAPIError.missingAPIKey
        }
        let configuration = configuration ?? .wcsLearning
        var results: [AdminLessonVideoDiscoveryResult] = []
        results.reserveCapacity(scriptLines.count)
        for line in scriptLines {
            let page = try await YouTubeSearchAPIClient.searchVideos(
                query: line.youTubeSearchQuery,
                configuration: configuration,
                maxResults: maxResultsPerLesson,
                session: session
            )
            let filtered = page.items.filter {
                isAllowed(snippet: $0, for: line.youTubeSearchQuery)
            }
            let snippets = snippetsForDisplay(
                relevanceFiltered: filtered,
                pageItems: page.items,
                maxResults: maxResultsPerLesson
            )
            results.append(AdminLessonVideoDiscoveryResult(scriptLine: line, snippets: snippets))
        }
        return results
    }

    /// Prefer title tokens overlapping the search query; if that yields nothing, fall back to API order
    /// so enrolled learners still get embeddable backups (strict relevance alone was too brittle).
    private static func snippetsForDisplay(
        relevanceFiltered: [YouTubeVideoSnippet],
        pageItems: [YouTubeVideoSnippet],
        maxResults: Int
    ) -> [YouTubeVideoSnippet] {
        let cap = max(1, min(maxResults, 50))
        if !relevanceFiltered.isEmpty {
            return Array(relevanceFiltered.prefix(cap))
        }
        let safe = pageItems.filter { snippet in
            !blockedTerms.contains(where: { snippet.title.lowercased().contains($0) })
        }
        return Array(safe.prefix(cap))
    }

    private static func isAllowed(snippet: YouTubeVideoSnippet, for query: String) -> Bool {
        let title = snippet.title.lowercased()
        if blockedTerms.contains(where: { title.contains($0) }) {
            return false
        }
        let tokens = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
            .filter { $0.count >= 4 }
        if tokens.isEmpty {
            return true
        }
        return tokens.contains(where: { title.contains($0) })
    }
}
