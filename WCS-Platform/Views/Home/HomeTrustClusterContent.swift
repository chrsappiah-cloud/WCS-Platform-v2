//
//  HomeTrustClusterContent.swift
//  WCS-Platform
//
//  Single source of truth for Discover “trust cluster” copy and placeholder testimonials.
//  Used by HomeTrustClusterViews, previews, and unit tests.
//

import Foundation

enum HomeTrustClusterContent: Sendable {
    static let supportEmail = "support@wcs.education"

    static let designerSectionEyebrow = "Course designer"
    static let designerName = "Dr Christopher Appiah-Thompson"
    static let designerBlurb = "Questions about cohorts, accessibility, or dementia-inclusive creative learning."
    static let emailCourseTeamLabel = "Email course team"

    static let testimonialsSectionTitle = "What learners say"
    static let testimonialsPlaceholderDisclaimer =
        "Placeholder voices for layout—replace with attributable learner feedback before production marketing."
    static let seeLearnerStoriesLabel = "See learner stories"

    struct LearnerTestimonialPage: Identifiable, Sendable, Equatable {
        let id: Int
        let quote: String
        let name: String
        let role: String
    }

    /// Placeholder quotes until verified learner feedback is wired from CMS or API.
    static let learnerTestimonialPages: [LearnerTestimonialPage] = [
        .init(
            id: 0,
            quote: "The course helped me rethink how creative arts can support dignity, memory, and connection in dementia care.",
            name: "Ama K.",
            role: "Learner"
        ),
        .init(
            id: 1,
            quote: "I appreciated the balance of practical dementia-care knowledge and creative digital activities I could adapt in my own setting.",
            name: "Pilot participant",
            role: "Support worker"
        ),
        .init(
            id: 2,
            quote: "The discussion cohort made the learning feel human, reflective, and directly relevant to community care practice.",
            name: "Allied health educator",
            role: "Early cohort"
        ),
    ]

    static var courseTeamMailURL: URL? {
        URL(string: "mailto:\(supportEmail)")
    }
}
