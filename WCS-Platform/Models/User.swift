//
//  User.swift
//  WCS-Platform
//

import Foundation

enum UserRole: String, Codable, Hashable {
    case learner
    case instructor
    case orgAdmin
    case admin
}

struct OrganizationMembership: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let organizationId: UUID
    let organizationName: String
    let role: UserRole
    let joinedAt: Date
    let isActive: Bool
}

struct User: Codable, Identifiable, Hashable {
    let id: UUID
    let email: String
    let name: String
    let photoURL: String?
    var role: UserRole
    var activeOrganizationId: UUID?
    var memberships: [OrganizationMembership]
    var subscriptions: [Subscription]
    var enrollments: [Enrollment]

    nonisolated var isPremium: Bool {
        subscriptions.contains { $0.status == .active }
    }

    nonisolated var isAdmin: Bool {
        role == .admin || role == .orgAdmin
    }

    nonisolated var isInstructor: Bool {
        role == .instructor || role == .orgAdmin || role == .admin
    }

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case photoURL
        case role
        case activeOrganizationId
        case memberships
        case subscriptions
        case enrollments
    }

    nonisolated init(
        id: UUID,
        email: String,
        name: String,
        photoURL: String?,
        role: UserRole = .learner,
        activeOrganizationId: UUID? = nil,
        memberships: [OrganizationMembership] = [],
        subscriptions: [Subscription],
        enrollments: [Enrollment]
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.photoURL = photoURL
        self.role = role
        self.activeOrganizationId = activeOrganizationId
        self.memberships = memberships
        self.subscriptions = subscriptions
        self.enrollments = enrollments
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        email = try c.decode(String.self, forKey: .email)
        name = try c.decode(String.self, forKey: .name)
        photoURL = try c.decodeIfPresent(String.self, forKey: .photoURL)
        role = try c.decodeIfPresent(UserRole.self, forKey: .role) ?? .learner
        activeOrganizationId = try c.decodeIfPresent(UUID.self, forKey: .activeOrganizationId)
        memberships = try c.decodeIfPresent([OrganizationMembership].self, forKey: .memberships) ?? []
        subscriptions = try c.decodeIfPresent([Subscription].self, forKey: .subscriptions) ?? []
        enrollments = try c.decodeIfPresent([Enrollment].self, forKey: .enrollments) ?? []
    }
}
