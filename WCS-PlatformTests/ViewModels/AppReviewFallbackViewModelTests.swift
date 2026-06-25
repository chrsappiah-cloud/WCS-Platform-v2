import Foundation
import Testing
@testable import WCS_Platform

@MainActor
struct AppReviewFallbackViewModelTests {
    @Test func programs_loadsBundledCatalogWhenRepositoryFails() async {
        let sut = CourseListViewModel(catalogRepository: FailingCatalogRepository())

        await sut.loadAvailableCourses()

        #expect(!sut.courses.isEmpty)
        #expect(sut.lastError == nil)
        #expect(sut.isLoading == false)
    }

    @Test func discussion_loadsBundledFeedWhenRepositoryFails() async {
        let sut = DiscussionViewModel(communityRepository: FailingCommunityRepository())

        await sut.loadAll()

        #expect(!sut.topics.isEmpty)
        #expect(!sut.posts.isEmpty)
        #expect(sut.pipelineStatus?.databaseReachable == true)
        #expect(sut.errorMessage == nil)
        #expect(sut.isLoading == false)
    }
}

private struct FailingCatalogRepository: CatalogRepository {
    func fetchDiscoverPayload() async throws -> DiscoverPayload {
        throw WCSAPIError(underlying: URLError(.timedOut), statusCode: nil, body: nil)
    }

    func fetchAvailableCourses() async throws -> [Course] {
        throw WCSAPIError(underlying: URLError(.timedOut), statusCode: nil, body: nil)
    }

    func fetchCourse(_ id: UUID) async throws -> Course {
        throw WCSAPIError(underlying: URLError(.timedOut), statusCode: nil, body: nil)
    }
}

private struct FailingCommunityRepository: CommunityRepository {
    func fetchDiscussionFeed(topicID: String?) async throws -> DiscussionFeedResponse {
        throw WCSAPIError(underlying: URLError(.timedOut), statusCode: nil, body: nil)
    }

    func createDiscussionPost(topicID: String, body: String, authorName: String) async throws -> DiscussionPost {
        throw WCSAPIError(underlying: URLError(.timedOut), statusCode: nil, body: nil)
    }

    func fetchPipelineHealthStatus() async throws -> PipelineHealthStatus {
        throw WCSAPIError(underlying: URLError(.timedOut), statusCode: nil, body: nil)
    }
}
