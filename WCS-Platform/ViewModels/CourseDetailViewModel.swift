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

    private let courseId: UUID
    private let catalogRepository: CatalogRepository
    private let learningRepository: LearningRepository

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
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            let loaded = try await catalogRepository.fetchCourse(courseId)
            course = loaded
            isEnrolled = loaded.isEnrolled
            await loadScholarshipAndCompanionVideos(for: loaded)
            Telemetry.event("course.load.success", attributes: ["courseId": loaded.id.uuidString])
        } catch let api as WCSAPIError {
            lastError = api
            Telemetry.event("course.load.failure", attributes: ["courseId": courseId.uuidString])
        } catch {
            lastError = WCSAPIError(underlying: error, statusCode: nil, body: nil)
            Telemetry.event("course.load.failure", attributes: ["courseId": courseId.uuidString])
        }
    }

    private func loadScholarshipAndCompanionVideos(for course: Course) async {
        do {
            crossrefScholarship = try await CrossrefWorksAPIClient.searchWorks(
                query: "\(course.title) learning pedagogy curriculum",
                rows: 4
            )
            Telemetry.event("crossref.fetch.success", attributes: ["courseId": course.id.uuidString])
        } catch {
            crossrefScholarship = []
            Telemetry.event("crossref.fetch.failure", attributes: ["courseId": course.id.uuidString])
        }

        companionVideoResults = []
        guard course.isEnrolled else { return }
        guard YouTubeSearchAPIClient.resolveAPIKey() != nil else { return }

        let lines = ModuleVideoDiscoveryPipeline.scriptLines(from: course)
        guard !lines.isEmpty else { return }

        let capped = Array(lines.prefix(6))
        do {
            companionVideoResults = try await ModuleVideoDiscoveryPipeline.resolveCompanionVideos(
                scriptLines: capped,
                maxResultsPerLesson: 2
            )
            Telemetry.event("youtube.companion.success", attributes: ["courseId": course.id.uuidString, "count": "\(companionVideoResults.count)"])
        } catch {
            companionVideoResults = []
            Telemetry.event("youtube.companion.failure", attributes: ["courseId": course.id.uuidString])
        }
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
