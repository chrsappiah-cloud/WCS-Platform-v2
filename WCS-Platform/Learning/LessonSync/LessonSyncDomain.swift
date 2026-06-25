//
//  LessonSyncDomain.swift
//  WCS-Platform
//

import Foundation

protocol LessonSyncAPI: Sendable {
    func fetchServerVersion(lessonID: String) async throws -> Int
    func push(_ progress: LessonSyncProgress) async throws -> LessonSyncReceipt
}

struct LessonSyncProgress: Sendable, Equatable {
    let lessonID: String
    let userID: String
    let percentComplete: Int
    let updatedAt: Date

    init(lessonID: String, userID: String, percentComplete: Int, updatedAt: Date) {
        self.lessonID = lessonID
        self.userID = userID
        self.percentComplete = percentComplete
        self.updatedAt = updatedAt
    }
}

struct LessonSyncReceipt: Sendable, Equatable {
    let syncID: UUID
    let serverVersion: Int
}

enum LessonSyncError: Error, Equatable {
    case conflict
    case offline
    case transport(String)
}
