import Foundation
import Testing
@testable import WCS_Platform

struct CourseModelTests {
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
