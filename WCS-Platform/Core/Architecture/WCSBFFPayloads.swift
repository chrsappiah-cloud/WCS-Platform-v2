//
//  WCSBFFPayloads.swift
//  WCS-Platform
//
//  Client-side BFF-shaped payloads that combine bounded contexts for mobile screens.
//

import Foundation

struct DiscoverProgramCard: Identifiable, Sendable {
    let id: UUID
    let course: Course
    let catalog: CatalogProjection
    let learning: LearningProjection
    let commerce: CommerceProjection
}

struct DiscoverPayload: Sendable {
    let identity: IdentityProjection
    let featuredPrograms: [DiscoverProgramCard]
    let allPrograms: [DiscoverProgramCard]
    let profile: ProfileProjection
    let analytics: AnalyticsProjection
    let generatedAt: Date
}

