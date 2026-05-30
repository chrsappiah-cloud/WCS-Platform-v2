//
//  AdminCourseDraft.swift
//  WCS-Platform
//

import Foundation

enum AdminCourseAccessTier: String, Codable, Hashable, CaseIterable, Identifiable {
    case freePublic

    var id: String { rawValue }

    nonisolated var label: String {
        switch self {
        case .freePublic:
            return "Free public"
        }
    }
}

struct AdminCourseDraft: Identifiable, Codable, Hashable {
    enum Status: String, Codable, Hashable {
        case draft
        case readyForReview
        case published
    }

    let id: UUID
    let createdAt: Date
    var updatedAt: Date
    let createdBy: String
    var title: String
    var summary: String
    var targetAudience: String
    var level: String
    var durationWeeks: Int
    var outcomes: [String]
    var modules: [AdminModuleDraft]
    var status: Status
    var accessTier: AdminCourseAccessTier
    var sourceReferences: [String]
    var promotionalCopy: [String]
    var funnelPreview: AIFunnelPreview?
    var reasoningReport: AIReasoningReport?
    var researchTrace: AIResearchTrace?
    var cohortSelection: AICohortSelection
    var reportFindings: [AICourseReportFinding]
}

struct AIFunnelPreview: Codable, Hashable {
    let headline: String
    let subheadline: String
    let callToAction: String
    let offerBullets: [String]
    let emailHooks: [String]
}

struct AIReasoningReport: Codable, Hashable {
    let focusQuestion: String
    let assumptions: [String]
    let reasoningSteps: [AIReasoningStep]
    let conclusion: String
    let confidenceScore: Double
}

struct AIReasoningStep: Codable, Hashable, Identifiable {
    let id: UUID
    let title: String
    let analysis: String
    let evidence: [String]
}

struct AIResearchTrace: Codable, Hashable {
    let engineName: String
    let retrievalMode: String
    let generatedQueries: [String]
    let evidenceCards: [AIEvidenceCard]
    let qualityGate: AIQualityGate
    let citationMap: [AICitationMapping]
}

struct AIEvidenceCard: Codable, Hashable, Identifiable {
    let id: UUID
    let title: String
    let source: String
    let snippet: String
    let relevanceScore: Double
    let freshnessScore: Double
}

struct AIQualityGate: Codable, Hashable {
    let passed: Bool
    let threshold: Double
    let score: Double
    let rationale: String
}

struct AICitationMapping: Codable, Hashable, Identifiable {
    let id: UUID
    let claim: String
    let sourceTitle: String
    let sourceSystem: String
}

enum AICohortType: String, Codable, Hashable, CaseIterable, Identifiable {
    case selfPaced
    case weeklyCohort
    case intensiveBootcamp
    case enterpriseTeam

    var id: String { rawValue }

    nonisolated var label: String {
        switch self {
        case .selfPaced:
            return "Self-paced"
        case .weeklyCohort:
            return "Weekly cohort"
        case .intensiveBootcamp:
            return "Intensive bootcamp"
        case .enterpriseTeam:
            return "Enterprise team cohort"
        }
    }
}

struct AICohortSelection: Codable, Hashable {
    let cohortType: AICohortType
    let recommendedSize: Int
    let rationale: String
}

struct AICourseReportFinding: Codable, Hashable, Identifiable {
    let id: UUID
    let title: String
    let detail: String
    let confidence: Double
}

struct AdminModuleDraft: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var goals: [String]
    var lessons: [AdminLessonDraft]
}

struct AdminLessonDraft: Identifiable, Codable, Hashable {
    enum Kind: String, Codable, Hashable {
        case video
        case reading
        case quiz
        case assignment
        case live
    }

    let id: UUID
    var title: String
    var kind: Kind
    var durationMinutes: Int
    var notes: String
}
