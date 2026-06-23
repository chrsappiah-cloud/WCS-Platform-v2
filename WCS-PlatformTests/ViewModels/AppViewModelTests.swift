import Foundation
import Testing
@testable import WCS_Platform

@MainActor
struct AppViewModelTests {
    @Test func bootstrapUser_whenRepositorySucceeds_setsAuthenticatedState() async {
        let mock = MockIdentityRepository()
        mock.currentUserResult = .success(TestFixtures.makeUser(role: .learner))
        let sut = AppViewModel(identityRepository: mock)

        await sut.bootstrapUser()

        #expect(sut.isAuthenticated)
        #expect(sut.user?.role == .learner)
    }

    @Test func bootstrapUser_whenRepositoryFails_clearsSession() async {
        let mock = MockIdentityRepository()
        mock.currentUserResult = .failure(URLError(.userAuthenticationRequired))
        let sut = AppViewModel(identityRepository: mock)

        await sut.bootstrapUser()

        #expect(!sut.isAuthenticated)
        #expect(sut.user == nil)
    }

    @Test func openTab_updatesSelectedTab() {
        let sut = AppViewModel(identityRepository: MockIdentityRepository())
        sut.openTab(.programs)
        #expect(sut.selectedTab == .programs)
    }
}
