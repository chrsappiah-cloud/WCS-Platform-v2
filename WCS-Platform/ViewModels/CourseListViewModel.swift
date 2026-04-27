//
//  CourseListViewModel.swift
//  WCS-Platform
//

import Combine
import Foundation

@MainActor
final class CourseListViewModel: ObservableObject {
    @Published var courses: [Course] = []
    @Published var searchText: String = ""
    /// Starts `true` so the first frame is never an empty `List` before `.task` runs.
    @Published var isLoading = true
    @Published var lastError: WCSAPIError?
    private let catalogRepository: CatalogRepository

    init(catalogRepository: CatalogRepository = WCSAppContainer.shared.catalog) {
        self.catalogRepository = catalogRepository
    }

    var filteredCourses: [Course] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return courses }
        return courses.filter { course in
            if course.title.lowercased().contains(q) { return true }
            if (course.subtitle ?? "").lowercased().contains(q) { return true }
            if (course.organizationName ?? "").lowercased().contains(q) { return true }
            if (course.description).lowercased().contains(q) { return true }
            return false
        }
    }

    func loadAvailableCourses() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            let payload = try await catalogRepository.fetchDiscoverPayload()
            courses = payload.allPrograms.map(\.course)
        } catch let api as WCSAPIError {
            lastError = api
        } catch {
            lastError = WCSAPIError(underlying: error, statusCode: nil, body: nil)
        }
    }
}
