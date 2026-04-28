//
//  CourseDetailViewModel.swift
//  WCS-Platform
//

import Combine
import Foundation

@MainActor
final class CourseDetailViewModel: ObservableObject {
    @Published var course: Course?
    /// Avoids a one-frame “empty” detail state before `loadCourse()` runs.
    @Published var isLoading = true
    @Published var lastError: WCSAPIError?
    @Published var isEnrolled = false

    /// Crossref open metadata for the program (students + public readers).
    @Published private(set) var crossrefScholarship: [CrossrefWorkSummary] = []

    /// Phase-4 companion clips: scripted lesson → YouTube Data API → embed (requires `YOUTUBE_DATA_API_KEY`).
    @Published private(set) var companionVideoResults: [LessonVideoDiscoveryResult] = []

    /// Stable catalog slice for Crossref / YouTube companion: avoids duplicate network + telemetry when `loadCourse` runs twice in a row with the same hydrated catalog (e.g. `.task` then `wcsLearningStateDidChange`).
    private func scholarshipCompanionFingerprint(for course: Course) -> String {
        let moduleCount = course.modules.count
        let videoLessonCount = course.modules.flatMap(\.lessons).filter { $0.type == .video }.count
        return "\(course.id.uuidString)|\(course.title)|\(course.isEnrolled)|\(moduleCount)|\(videoLessonCount)"
    }

    private var lastScholarshipCompanionFingerprint: String?

    private let courseId: UUID
    private let catalogRepository: CatalogRepository
    private let learningRepository: LearningRepository

    /// Cancels overlapping loads so `.task` + `wcsLearningStateDidChange` do not each fire Crossref / YouTube in parallel.
    private var loadCourseTask: Task<Void, Never>?

    init(
        courseId: UUID,
        catalogRepository: CatalogRepository = WCSAppContainer.shared.catalog,
        learningRepository: LearningRepository = WCSAppContainer.shared.learning
    ) {
        self.courseId = courseId
        self.catalogRepository = catalogRepository
        self.learningRepository = learningRepository
    }

    func loadCourse() async {
        loadCourseTask?.cancel()
        let task = Task { @MainActor in
            await self.performLoadCourse()
        }
        loadCourseTask = task
        await task.value
    }

    private func performLoadCourse() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            try Task.checkCancellation()
            let loaded = try await catalogRepository.fetchCourse(courseId)
            try Task.checkCancellation()
            let fingerprint = scholarshipCompanionFingerprint(for: loaded)
            course = loaded
            isEnrolled = loaded.isEnrolled

            let wantsCompanion =
                loaded.isEnrolled
                && YouTubeSearchAPIClient.resolveAPIKey() != nil
                && loaded.modules.flatMap(\.lessons).contains { $0.type == .video }

            if let last = lastScholarshipCompanionFingerprint, last == fingerprint {
                // Same catalog slice as last load: skip duplicate Crossref/YouTube work unless we still
                // need companion rows (e.g. prior YouTube failure left `companionVideoResults` empty).
                if wantsCompanion && companionVideoResults.isEmpty {
                    // Fall through and retry.
                } else {
                    return
                }
            }

            await loadScholarshipAndCompanionVideos(for: loaded)
            try Task.checkCancellation()
            lastScholarshipCompanionFingerprint = fingerprint
            Telemetry.event("course.load.success", attributes: ["courseId": loaded.id.uuidString])
        } catch is CancellationError {
            return
        } catch let api as WCSAPIError {
            if Task.isCancelled { return }
            lastError = api
            Telemetry.event("course.load.failure", attributes: ["courseId": courseId.uuidString])
        } catch {
            if Task.isCancelled || Self.isCancellationLikeError(error) { return }
            lastError = WCSAPIError(underlying: error, statusCode: nil, body: nil)
            Telemetry.event("course.load.failure", attributes: ["courseId": courseId.uuidString])
        }
    }

    private static func isCancellationLikeError(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let ns = error as NSError
        return ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled
    }

    /// Classifies networking errors so analytics dashboards can separate transient timeouts/offline conditions from genuine failures.
    private static func networkFailureReason(_ error: Error) -> String {
        let ns = error as NSError
        guard ns.domain == NSURLErrorDomain else { return "other" }
        switch ns.code {
        case NSURLErrorTimedOut: return "timeout"
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost: return "offline"
        case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorDNSLookupFailed: return "dns_or_host"
        default: return "url_error_\(ns.code)"
        }
    }

    private func loadScholarshipAndCompanionVideos(for course: Course) async {
        do {
            crossrefScholarship = try await CrossrefWorksAPIClient.searchWorks(
                query: "\(course.title) learning pedagogy curriculum",
                rows: 4
            )
            try Task.checkCancellation()
            Telemetry.event("crossref.fetch.success", attributes: ["courseId": course.id.uuidString])
        } catch {
            if Task.isCancelled || Self.isCancellationLikeError(error) { return }
            crossrefScholarship = []
            Telemetry.event("crossref.fetch.failure", attributes: [
                "courseId": course.id.uuidString,
                "reason": Self.networkFailureReason(error)
            ])
        }

        companionVideoResults = []
        guard course.isEnrolled else { return }
        guard YouTubeSearchAPIClient.resolveAPIKey() != nil else { return }

        let lines = ModuleVideoDiscoveryPipeline.scriptLines(from: course)
        guard !lines.isEmpty else { return }

        let capped = Array(lines.prefix(12))
        do {
            companionVideoResults = try await ModuleVideoDiscoveryPipeline.resolveCompanionVideos(
                scriptLines: capped,
                maxResultsPerLesson: 6
            )
            try Task.checkCancellation()
            Telemetry.event("youtube.companion.success", attributes: ["courseId": course.id.uuidString, "count": "\(companionVideoResults.count)"])
        } catch {
            if Task.isCancelled || Self.isCancellationLikeError(error) { return }
            companionVideoResults = []
            Telemetry.event("youtube.companion.failure", attributes: [
                "courseId": course.id.uuidString,
                "reason": Self.networkFailureReason(error)
            ])
        }
    }

    /// YouTube Data API snippets for this lesson (same pipeline as the course overview “Phase 4” block), for in-lesson backup playback.
    func companionSnippets(forLessonId lessonId: UUID) -> [YouTubeVideoSnippet] {
        companionVideoResults.first(where: { $0.scriptLine.id == lessonId })?.snippets ?? []
    }

    /// Unit-test seam: simulates YouTube companion discovery without network.
    func injectCompanionResultsForTests(_ results: [LessonVideoDiscoveryResult]) {
        companionVideoResults = results
    }

    func enroll() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            _ = try await learningRepository.enroll(programId: courseId)
            await loadCourse()
        } catch let api as WCSAPIError {
            lastError = api
        } catch {
            lastError = WCSAPIError(underlying: error, statusCode: nil, body: nil)
        }
    }
}
