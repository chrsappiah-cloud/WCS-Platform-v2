import Foundation
import Testing
@testable import WCS_Platform

struct CourseModelTests {
    @Test func init_supportsOptionalPriceAndSubtitle() {
        let free = TestFixtures.makeCourse(title: "Free", price: nil)
        let paid = TestFixtures.makeCourse(title: "Paid", price: 49)
        #expect(free.price == nil)
        #expect(paid.price == 49)
    }

    @Test func equality_comparesFullCourseIdentity() {
        let id = UUID()
        let left = TestFixtures.makeCourse(title: "Same", price: nil)
        let right = Course(
            id: id,
            title: "Same",
            subtitle: left.subtitle,
            description: left.description,
            thumbnailURL: left.thumbnailURL,
            coverURL: left.coverURL,
            durationSeconds: left.durationSeconds,
            price: left.price,
            isEnrolled: left.isEnrolled,
            isOwned: left.isOwned,
            isUnlockedBySubscription: left.isUnlockedBySubscription,
            rating: left.rating,
            reviewCount: left.reviewCount,
            organizationName: left.organizationName,
            level: left.level,
            effortDescription: left.effortDescription,
            spokenLanguages: left.spokenLanguages,
            modules: left.modules,
            courseReport: left.courseReport
        )
        let same = Course(
            id: left.id,
            title: left.title,
            subtitle: left.subtitle,
            description: left.description,
            thumbnailURL: left.thumbnailURL,
            coverURL: left.coverURL,
            durationSeconds: left.durationSeconds,
            price: left.price,
            isEnrolled: left.isEnrolled,
            isOwned: left.isOwned,
            isUnlockedBySubscription: left.isUnlockedBySubscription,
            rating: left.rating,
            reviewCount: left.reviewCount,
            organizationName: left.organizationName,
            level: left.level,
            effortDescription: left.effortDescription,
            spokenLanguages: left.spokenLanguages,
            modules: left.modules,
            courseReport: left.courseReport
        )
        #expect(left == same)
        #expect(left != right)
    }

    @Test func encodeRoundTrip_preservesCourseReport() throws {
        let report = CourseReportSnapshot(
            designGoals: "Goals",
            moduleOverview: "Overview",
            learningOutcomes: ["Outcome"],
            cohortRecommendation: "Weekly",
            findings: []
        )
        var course = TestFixtures.makeCourse()
        course.courseReport = report
        let data = try JSONEncoder().encode(course)
        let decoded = try JSONDecoder().decode(Course.self, from: data)
        #expect(decoded.courseReport == report)
    }
}
