import Foundation
import Testing
@testable import WCS_Platform

struct ContentPublishIntegrationTests {
    @Test func manualBackupPublish_appearsInLearnerCatalog() async throws {
        await AdminCourseDraftStore.shared.clearAll()
        await MockLearningStore.shared.deleteBlockedAICourses()

        let previousAdminMode = UserDefaults.standard.bool(forKey: "wcs.mockAdminMode")
        defer { UserDefaults.standard.set(previousAdminMode, forKey: "wcs.mockAdminMode") }
        UserDefaults.standard.set(true, forKey: "wcs.mockAdminMode")

        let runID = UUID().uuidString.prefix(6)
        let draft = try await AdminCourseDraftStore.shared.createManualBackupDraft(
            createdBy: "admin@wcs",
            accessTier: .freePublic,
            courseTitle: "Integration Publish \(runID)",
            summary: "Integration summary.",
            moduleTitle: "Module",
            videoTitle: "Video",
            videoURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8",
            readingTitle: "Reading",
            readingMaterial: "Notes.",
            quizTitle: "Quiz",
            quizPrompt: "Q1",
            assignmentTitle: "Assignment",
            assignmentBrief: "Brief."
        )
        try await AdminCourseDraftStore.shared.markPublished(draft.id)

        let published = await MockLearningStore.shared.snapshotCourse(draft.id)
        #expect(published?.title.contains("Integration Publish") == true)
    }
}
