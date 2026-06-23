import Foundation
import Testing
@testable import WCS_Platform

struct NetworkChaosHarnessTests {
    @Test
    func youTubeSearchRejectsWhitespaceQueryBeforeTransport() async {
        do {
            _ = try await YouTubeSearchAPIClient.searchVideos(query: "   ", maxResults: 1)
            Issue.record("Expected invalid query to throw before URLSession work.")
        } catch let error as YouTubeAPIError {
            if case .invalidQuery = error {
                return
            } else {
                Issue.record("Expected .invalidQuery, got \(error).")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func decodeCrossrefEmptyPayloadIsStable() throws {
        let data = Data(#"{"message":{"items":[]}}"#.utf8)
        let works = try CrossrefWorksAPIClient.decodeWorks(from: data)
        #expect(works.isEmpty)
    }

    @Test
    func decodeYouTubeMalformedPayloadThrows() {
        let data = Data(#"{"items":[{"snippet":{}}]}"#.utf8)
        #expect(throws: Error.self) {
            _ = try YouTubeSearchAPIClient.decodePage(from: data)
        }
    }

    @Test
    func lessonProgressPayloadEncodesStableAdapterBoundary() throws {
        let courseId = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let moduleId = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
        let lessonId = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
        let payload = LessonProgressRequest(
            courseId: courseId,
            moduleId: moduleId,
            lessonId: lessonId,
            complete: true
        )

        let data = try JSONEncoder().encode(payload)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["courseId"] as? String == courseId.uuidString)
        #expect(object["moduleId"] as? String == moduleId.uuidString)
        #expect(object["lessonId"] as? String == lessonId.uuidString)
        #expect(object["complete"] as? Bool == true)
    }

    @Test
    func lessonWatchProgressPayloadEncodesResumeBoundary() throws {
        let courseId = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let moduleId = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
        let lessonId = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
        let payload = LessonWatchProgressRequest(
            courseId: courseId,
            moduleId: moduleId,
            lessonId: lessonId,
            positionSeconds: 88.5,
            durationSeconds: 600
        )

        let data = try JSONEncoder().encode(payload)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["courseId"] as? String == courseId.uuidString)
        #expect(object["moduleId"] as? String == moduleId.uuidString)
        #expect(object["lessonId"] as? String == lessonId.uuidString)
        #expect(object["positionSeconds"] as? Double == 88.5)
        #expect(object["durationSeconds"] as? Double == 600)
    }
}
