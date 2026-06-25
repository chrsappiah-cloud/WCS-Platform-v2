//
//  ShadowLessonSyncAPI.swift
//  WCS-Platform
//

import Foundation

protocol LessonSyncShadowEventRecorder: Sendable {
    func record(category: String, level: String, message: String, metadata: [String: String]) async
}

struct TelemetryLessonSyncShadowEventRecorder: LessonSyncShadowEventRecorder {
    func record(category: String, level: String, message: String, metadata: [String: String]) async {
        var attributes = metadata
        attributes["level"] = level
        attributes["message"] = message
        Telemetry.event(category, attributes: attributes)
    }
}

final class ShadowLessonSyncAPI: LessonSyncAPI {
    private let primary: any LessonSyncAPI
    private let shadow: any LessonSyncAPI
    private let recorder: any LessonSyncShadowEventRecorder

    init(
        primary: any LessonSyncAPI,
        shadow: any LessonSyncAPI,
        recorder: any LessonSyncShadowEventRecorder = TelemetryLessonSyncShadowEventRecorder()
    ) {
        self.primary = primary
        self.shadow = shadow
        self.recorder = recorder
    }

    func fetchServerVersion(lessonID: String) async throws -> Int {
        let shadowTask = Task {
            try await shadow.fetchServerVersion(lessonID: lessonID)
        }
        let primaryVersion = try await primary.fetchServerVersion(lessonID: lessonID)

        Task { [recorder] in
            do {
                let shadowVersion = try await shadowTask.value
                if shadowVersion != primaryVersion {
                    await recorder.record(
                        category: "lesson_sync_shadow",
                        level: "warning",
                        message: "Version mismatch primary vs shadow",
                        metadata: [
                            "lesson_id": lessonID,
                            "primary": "\(primaryVersion)",
                            "shadow": "\(shadowVersion)",
                        ]
                    )
                }
            } catch {
                await recorder.record(
                    category: "lesson_sync_shadow",
                    level: "error",
                    message: "Shadow fetch failed",
                    metadata: [
                        "lesson_id": lessonID,
                        "error": String(describing: error),
                    ]
                )
            }
        }

        return primaryVersion
    }

    func push(_ progress: LessonSyncProgress) async throws -> LessonSyncReceipt {
        Task { [shadow, recorder] in
            do {
                _ = try await shadow.push(progress)
            } catch {
                await recorder.record(
                    category: "lesson_sync_shadow",
                    level: "error",
                    message: "Shadow push failed",
                    metadata: [
                        "lesson_id": progress.lessonID,
                        "user_id": progress.userID,
                        "error": String(describing: error),
                    ]
                )
            }
        }

        return try await primary.push(progress)
    }
}
