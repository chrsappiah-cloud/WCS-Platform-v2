import Foundation
@testable import WCS_Platform

final class MockIdentityRepository: IdentityRepository {
    var currentUserResult: Result<User, Error> = .success(TestFixtures.makeUser())
    var logInResult: Result<User, Error>?
    var signUpResult: Result<User, Error>?
    var lastLogInEmail: String?
    var lastLogInPassword: String?

    func currentUser() async throws -> User {
        try currentUserResult.get()
    }

    func signUp(email: String, password: String, displayName: String) async throws -> User {
        if let signUpResult { return try signUpResult.get() }
        return try currentUserResult.get()
    }

    func logIn(email: String, password: String) async throws -> User {
        lastLogInEmail = email
        lastLogInPassword = password
        if let logInResult { return try logInResult.get() }
        return try currentUserResult.get()
    }

    func switchOrganization(_ organizationId: UUID) async throws -> User {
        var user = try currentUserResult.get()
        user.activeOrganizationId = organizationId
        return user
    }
}
