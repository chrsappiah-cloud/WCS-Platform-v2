import Foundation
import Testing
@testable import WCS_Platform

struct LessonSyncHTTPAPITests {
    @Test
    func fetchServerVersion_buildsExpectedRequestAndDecodesVersion() async throws {
        let transport = InMemoryHTTPClient(response: HTTPResponse(
            statusCode: 200,
            body: Data(#"{"version":7}"#.utf8)
        ))
        let api = LessonSyncHTTPAPI(
            baseURL: URL(string: "https://api.example.test/v1")!,
            client: transport
        )

        let version = try await api.fetchServerVersion(lessonID: "lesson-1")

        #expect(version == 7)
        #expect(transport.requests == [
            HTTPRequest(url: URL(string: "https://api.example.test/v1/lessons/lesson-1/sync-version")!)
        ])
    }

    @Test
    func push_encodesProgressAndDecodesReceipt() async throws {
        let syncID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let transport = InMemoryHTTPClient(response: HTTPResponse(
            statusCode: 200,
            body: Data(#"{"sync_id":"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE","server_version":9}"#.utf8)
        ))
        let api = LessonSyncHTTPAPI(
            baseURL: URL(string: "https://api.example.test/v1/")!,
            client: transport
        )
        let updatedAt = Date(timeIntervalSince1970: 1_704_067_200)

        let receipt = try await api.push(LessonSyncProgress(
            lessonID: "lesson-2",
            userID: "user-1",
            percentComplete: 42,
            updatedAt: updatedAt
        ))

        #expect(receipt == LessonSyncReceipt(syncID: syncID, serverVersion: 9))
        guard let request = transport.requests.first else {
            Issue.record("Expected one HTTP request.")
            return
        }
        #expect(request.url == URL(string: "https://api.example.test/v1/lessons/lesson-2/progress")!)
        #expect(request.method == "POST")
        #expect(request.headers["Content-Type"] == "application/json")

        guard let requestBody = request.body else {
            Issue.record("Expected encoded request body.")
            return
        }
        guard let object = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any] else {
            Issue.record("Expected JSON object request body.")
            return
        }
        #expect(object["user_id"] as? String == "user-1")
        #expect(object["percent_complete"] as? Int == 42)
        #expect(object["updated_at"] as? String == "2024-01-01T00:00:00Z")
    }

    @Test
    func push_mapsConflictStatusToDomainConflict() async {
        let transport = InMemoryHTTPClient(response: HTTPResponse(statusCode: 409))
        let api = LessonSyncHTTPAPI(baseURL: URL(string: "https://api.example.test")!, client: transport)

        await #expect(throws: LessonSyncError.conflict) {
            _ = try await api.push(LessonSyncProgress(
                lessonID: "lesson-3",
                userID: "user-1",
                percentComplete: 100,
                updatedAt: Date(timeIntervalSince1970: 0)
            ))
        }
    }

    @Test
    func fetchServerVersion_mapsOfflineURLErrorToDomainOffline() async {
        let transport = InMemoryHTTPClient(error: URLError(.notConnectedToInternet))
        let api = LessonSyncHTTPAPI(baseURL: URL(string: "https://api.example.test")!, client: transport)

        await #expect(throws: LessonSyncError.offline) {
            _ = try await api.fetchServerVersion(lessonID: "lesson-4")
        }
    }

    @Test
    func fetchServerVersion_includesStatusSnippetForUnhandledHTTPError() async {
        let transport = InMemoryHTTPClient(response: HTTPResponse(
            statusCode: 503,
            body: Data("maintenance window".utf8)
        ))
        let api = LessonSyncHTTPAPI(baseURL: URL(string: "https://api.example.test")!, client: transport)

        await #expect(throws: LessonSyncError.transport("HTTP 503: maintenance window")) {
            _ = try await api.fetchServerVersion(lessonID: "lesson-5")
        }
    }
}

private final class InMemoryHTTPClient: HTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private let response: HTTPResponse?
    private let error: Error?
    private var storedRequests: [HTTPRequest] = []

    var requests: [HTTPRequest] {
        lock.withLock { storedRequests }
    }

    init(response: HTTPResponse) {
        self.response = response
        self.error = nil
    }

    init(error: Error) {
        self.response = nil
        self.error = error
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        lock.withLock { storedRequests.append(request) }
        if let error { throw error }
        guard let response else {
            throw LessonSyncHTTPAPITestError.missingResponse
        }
        return response
    }
}

private enum LessonSyncHTTPAPITestError: Error {
    case missingResponse
}
