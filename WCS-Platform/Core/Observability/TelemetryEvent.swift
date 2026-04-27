//
//  TelemetryEvent.swift
//  WCS-Platform
//

import Foundation

enum TelemetryEvent: String {
    case appLaunched = "app_launched"
    case discoverViewed = "discover_viewed"
    case catalogItemOpened = "catalog_item_opened"
    case auditStarted = "audit_started"
    case lessonStarted = "lesson_started"
    case lessonCompleted = "lesson_completed"
    case quizStarted = "quiz_started"
    case quizSubmitted = "quiz_submitted"
    case courseCompleted = "course_completed"
    case upgradeViewed = "upgrade_viewed"
    case upgradeStarted = "upgrade_started"
    case upgradeCompleted = "upgrade_completed"
    case certificateViewed = "certificate_viewed"
    case profileViewed = "profile_viewed"
    case profileShared = "profile_shared"
}
