import Foundation
import Testing
@testable import WCS_Platform

@MainActor
struct AdminCourseCreatorViewModelTests {
    @Test func unlock_withValidCode_unlocksStudio() {
        let sut = AdminCourseCreatorViewModel()
        sut.accessCodeInput = AppEnvironment.adminAccessCode
        sut.unlock()
        #expect(sut.isUnlocked)
        #expect(sut.errorMessage == nil)
    }

    @Test func unlock_withInvalidCode_setsError() {
        let sut = AdminCourseCreatorViewModel()
        sut.accessCodeInput = "wrong-code"
        sut.unlock()
        #expect(!sut.isUnlocked)
        #expect(sut.errorMessage?.contains("Invalid") == true)
    }

    @Test func canGenerate_withStudioDefaults_isTrue() {
        let sut = AdminCourseCreatorViewModel()
        #expect(sut.canGenerate)
    }

    @Test func canCreateManualBackup_whenAllFieldsPresent_isTrue() {
        let sut = AdminCourseCreatorViewModel()
        sut.manualCourseTitle = "Course"
        sut.manualSummary = "Summary"
        sut.manualModuleTitle = "Module"
        sut.manualVideoTitle = "Video"
        sut.manualVideoURL = "https://example.com/v.mp4"
        sut.manualReadingTitle = "Reading"
        sut.manualReadingMaterial = "Body"
        sut.manualQuizTitle = "Quiz"
        sut.manualQuizPrompt = "Q1"
        sut.manualAssignmentTitle = "Assignment"
        sut.manualAssignmentBrief = "Brief"
        #expect(sut.canCreateManualBackup)
    }
}
