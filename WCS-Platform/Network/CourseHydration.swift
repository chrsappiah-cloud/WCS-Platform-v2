//
//  CourseHydration.swift
//  WCS-Platform
//

import Foundation

enum CourseHydration {
    nonisolated static func apply(
        base: Course,
        enrolledCourseIds: Set<UUID>,
        completedLessonIds: Set<UUID>,
        submittedAssignments: [UUID: Submission],
        watchResumeByLessonId: [UUID: Double] = [:]
    ) -> Course {
        let enrolled = enrolledCourseIds.contains(base.id)
        let modules = base.modules.map { module in
            Module(
                id: module.id,
                title: module.title,
                description: module.description,
                order: module.order,
                isAvailable: module.isAvailable,
                isUnlocked: module.isUnlocked,
                lessons: module.lessons.map { lesson in
                    let completed = completedLessonIds.contains(lesson.id)
                    let assignment: Assignment?
                    if let a = lesson.assignment {
                        if let submission = submittedAssignments[a.id] {
                            assignment = Assignment(
                                id: a.id,
                                title: a.title,
                                description: a.description,
                                dueDate: a.dueDate,
                                maxAttempts: a.maxAttempts,
                                isSubmitted: true,
                                submission: submission
                            )
                        } else {
                            assignment = a
                        }
                    } else {
                        assignment = nil
                    }
                    let serverResume = watchResumeByLessonId[lesson.id] ?? lesson.serverResumePositionSeconds
                    return Lesson(
                        id: lesson.id,
                        title: lesson.title,
                        subtitle: lesson.subtitle,
                        type: lesson.type,
                        videoURL: lesson.videoURL,
                        durationSeconds: lesson.durationSeconds,
                        isCompleted: completed,
                        isAvailable: lesson.isAvailable,
                        isUnlocked: lesson.isUnlocked,
                        reading: lesson.reading,
                        quiz: lesson.quiz,
                        assignment: assignment,
                        captionTracks: lesson.captionTracks,
                        serverResumePositionSeconds: serverResume
                    )
                }
            )
        }
        return Course(
            id: base.id,
            title: base.title,
            subtitle: base.subtitle,
            description: base.description,
            thumbnailURL: base.thumbnailURL,
            coverURL: base.coverURL,
            durationSeconds: base.durationSeconds,
            price: base.price,
            isEnrolled: enrolled,
            isOwned: enrolled ? true : base.isOwned,
            isUnlockedBySubscription: base.isUnlockedBySubscription,
            rating: base.rating,
            reviewCount: base.reviewCount,
            organizationName: base.organizationName,
            level: base.level,
            effortDescription: base.effortDescription,
            spokenLanguages: base.spokenLanguages,
            modules: modules,
            courseReport: base.courseReport
        )
    }

    nonisolated static func progressFraction(for course: Course) -> Double {
        let total = max(1, course.modules.reduce(0) { $0 + $1.lessons.count })
        let done = course.modules.flatMap(\.lessons).filter(\.isCompleted).count
        return Double(done) / Double(total)
    }
}
