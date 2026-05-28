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
            switch error {
            case .invalidQuery:
                #expect(true)
            default:
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
}
