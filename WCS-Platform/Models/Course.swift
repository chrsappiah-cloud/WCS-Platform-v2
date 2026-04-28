//
//  Course.swift
//  WCS-Platform
//

import Foundation

struct Course: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String?
    let description: String
    let thumbnailURL: String
    let coverURL: String?
    let durationSeconds: Int
    let price: Decimal?
    let isEnrolled: Bool
    let isOwned: Bool
    let isUnlockedBySubscription: Bool
    let rating: Double?
    let reviewCount: Int
    /// Partner or school line (similar to “MITx”, “HarvardX” on open learning catalogs).
    let organizationName: String?
    let level: String?
    let effortDescription: String?
    let spokenLanguages: [String]?
    let modules: [Module]
    var courseReport: CourseReportSnapshot?

    nonisolated init(
        id: UUID,
        title: String,
        subtitle: String?,
        description: String,
        thumbnailURL: String,
        coverURL: String?,
        durationSeconds: Int,
        price: Decimal?,
        isEnrolled: Bool,
        isOwned: Bool,
        isUnlockedBySubscription: Bool,
        rating: Double?,
        reviewCount: Int,
        organizationName: String?,
        level: String?,
        effortDescription: String?,
        spokenLanguages: [String]?,
        modules: [Module],
        courseReport: CourseReportSnapshot? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.thumbnailURL = thumbnailURL
        self.coverURL = coverURL
        self.durationSeconds = durationSeconds
        self.price = price
        self.isEnrolled = isEnrolled
        self.isOwned = isOwned
        self.isUnlockedBySubscription = isUnlockedBySubscription
        self.rating = rating
        self.reviewCount = reviewCount
        self.organizationName = organizationName
        self.level = level
        self.effortDescription = effortDescription
        self.spokenLanguages = spokenLanguages
        self.modules = modules
        self.courseReport = courseReport
    }
}

struct CourseReportSnapshot: Codable, Hashable {
    let designGoals: String
    let moduleOverview: String
    let learningOutcomes: [String]
    let cohortRecommendation: String
    let findings: [CourseReportFinding]
}

struct CourseReportFinding: Codable, Hashable, Identifiable {
    let id: UUID
    let title: String
    let detail: String
    let confidence: Double
}

extension Course {
    nonisolated var totalLessons: Int {
        modules.reduce(0) { $0 + $1.lessons.count }
    }

    nonisolated var displayLanguages: String {
        guard let langs = spokenLanguages, !langs.isEmpty else { return "English" }
        return langs.joined(separator: ", ")
    }

    nonisolated func copy(
        isEnrolled: Bool? = nil,
        isOwned: Bool? = nil,
        modules: [Module]? = nil
    ) -> Course {
        Course(
            id: id,
            title: title,
            subtitle: subtitle,
            description: description,
            thumbnailURL: thumbnailURL,
            coverURL: coverURL,
            durationSeconds: durationSeconds,
            price: price,
            isEnrolled: isEnrolled ?? self.isEnrolled,
            isOwned: isOwned ?? self.isOwned,
            isUnlockedBySubscription: isUnlockedBySubscription,
            rating: rating,
            reviewCount: reviewCount,
            organizationName: organizationName,
            level: level,
            effortDescription: effortDescription,
            spokenLanguages: spokenLanguages,
            modules: modules ?? self.modules,
            courseReport: courseReport
        )
    }
}

struct CourseListResponse: Codable {
    let courses: [Course]
}

struct LessonProgressRequest: Codable {
    let courseId: UUID
    let moduleId: UUID
    let lessonId: UUID
    let complete: Bool
}

/// BFF payload for periodic watch position (Udemy-style resume across devices).
struct LessonWatchProgressRequest: Codable {
    let courseId: UUID
    let moduleId: UUID
    let lessonId: UUID
    let positionSeconds: Double
    let durationSeconds: Double
}

struct EnrollmentCreateRequest: Codable {
    let courseId: UUID
}
