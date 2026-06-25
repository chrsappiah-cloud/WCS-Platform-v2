import Foundation
import Testing
@testable import WCS_Platform

struct ShadowLessonSyncAPITests {
    @Test
    func fetchServerVersion_returnsPrimaryValueAndRecordsMismatch() async throws {
        let primary = StubLessonSyncAPI(version: 7)
        let shadow = StubLessonSyncAPI(version: 8)
        let recorder = CapturingShadowRecorder()
        let api = ShadowLessonSyncAPI(primary: primary, shadow: shadow, recorder: recorder)

        let version = try await api.fetchServerVersion(lessonID: "lesson-1")
        try await Task.sleep(nanoseconds: 20_000_000)

        #expect(version == 7)
        #expect(await recorder.events.contains { event in
            event.message == "Version mismatch primary vs shadow"
                && event.metadata["primary"] == "7"
                && event.metadata["shadow"] == "8"
        })
    }

    @Test
    func push_returnsPrimaryReceiptWhenShadowFails() async throws {
        let receipt = LessonSyncReceipt(
            syncID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            serverVersion: 3
        )
        let primary = StubLessonSyncAPI(receipt: receipt)
        let shadow = StubLessonSyncAPI(error: LessonSyncError.transport("shadow down"))
        let recorder = CapturingShadowRecorder()
        let api = ShadowLessonSyncAPI(primary: primary, shadow: shadow, recorder: recorder)

        let actual = try await api.push(LessonSyncProgress(
            lessonID: "lesson-1",
            userID: "user-1",
            percentComplete: 25,
            updatedAt: Date(timeIntervalSince1970: 0)
        ))
        let recordedFailure = await recorder.waitForEvent(message: "Shadow push failed")

        #expect(actual == receipt)
        #expect(recordedFailure)
    }
}

private final class StubLessonSyncAPI: LessonSyncAPI, @unchecked Sendable {
    private let version: Int
    private let receipt: LessonSyncReceipt
    private let error: Error?

    init(
        version: Int = 1,
        receipt: LessonSyncReceipt = LessonSyncReceipt(syncID: UUID(), serverVersion: 1),
        error: Error? = nil
    ) {
        self.version = version
        self.receipt = receipt
        self.error = error
    }

    func fetchServerVersion(lessonID: String) async throws -> Int {
        if let error { throw error }
        return version
    }

    func push(_ progress: LessonSyncProgress) async throws -> LessonSyncReceipt {
        if let error { throw error }
        return receipt
    }
}

private actor CapturingShadowRecorder: LessonSyncShadowEventRecorder {
    struct Event: Equatable {
        let category: String
        let level: String
        let message: String
        let metadata: [String: String]
    }

    private(set) var events: [Event] = []

    func record(category: String, level: String, message: String, metadata: [String: String]) {
        events.append(Event(category: category, level: level, message: message, metadata: metadata))
    }

    func waitForEvent(message: String) async -> Bool {
        for _ in 0..<50 {
            if events.contains(where: { $0.message == message }) {
                return true
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return false
    }
}
