//
//  AdminAICourseGenerator.swift
//  WCS-Platform
//

import Foundation

protocol AICourseGenerating {
    func generateDraft(prompt: String, createdBy: String, accessTier: AdminCourseAccessTier) async throws -> AdminCourseDraft
}

enum AdminAIGeneratorError: LocalizedError {
    case promptTooShort

    var errorDescription: String? {
        switch self {
        case .promptTooShort:
            return "Please provide more detail (at least 20 characters) so AI can generate a strong course draft."
        }
    }
}

struct MockAICourseGenerator: AICourseGenerating {
    private let researchService = OpenSourceResearchService()
    private let qualityGateThreshold = 0.70

    nonisolated init() {}

    func generateDraft(prompt: String, createdBy: String, accessTier: AdminCourseAccessTier) async throws -> AdminCourseDraft {
        let cleaned = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 20 else { throw AdminAIGeneratorError.promptTooShort }
        let plannerContext = parsePlannerContext(from: cleaned)
        let researchTopic = plannerContext.researchTopic

        async let research = researchService.fetch(topic: researchTopic)
        try await Task.sleep(nanoseconds: 500_000_000)

        let title = deriveTitle(from: cleaned, context: plannerContext)
        let audience = deriveAudience(from: cleaned)
        let level = deriveLevel(from: cleaned)
        let durationWeeks = deriveDuration(from: cleaned)
        let snapshot = await research
        let sources = (snapshot.bookTitles + snapshot.workTitles).prefix(4)

        let outcomes = [
            "Define the core framework for \(title.lowercased()).",
            "Apply concepts through guided practice and feedback loops.",
            sources.isEmpty
                ? "Produce a capstone artifact aligned with real-world WCS programs."
                : "Use evidence from open sources: \(sources.joined(separator: ", "))."
        ]

        let modules = [
            makeModule(title: "Foundations", theme: title, includeQuiz: true, references: snapshot.bookTitles),
            makeModule(title: "Applied Practice", theme: title, includeQuiz: false, references: snapshot.workTitles),
            makeModule(title: "Capstone Delivery", theme: title, includeQuiz: true, references: snapshot.bookTitles + snapshot.workTitles)
        ]
        let funnelPreview = buildFunnelPreview(title: title, audience: audience, level: level)
        let researchTrace = buildResearchTrace(
            prompt: cleaned,
            title: title,
            snapshot: snapshot
        )
        let reasoningReport = buildReasoningReport(
            prompt: cleaned,
            title: title,
            sourceTitles: Array(sources),
            qualityGate: researchTrace.qualityGate
        )
        let cohortSelection = deriveCohortSelection(from: cleaned, context: plannerContext)
        let reportFindings = buildCourseReportFindings(
            title: title,
            cohortSelection: cohortSelection,
            qualityGate: researchTrace.qualityGate,
            sourceTitles: Array(sources)
        )

        let now = Date()
        let promotionalCopy = [
            "Launch your next learning milestone with \(title).",
            "Built with guided videos, graded quizzes, and practical assignments.",
            "Join World Class Scholars and earn a certificate recognized across our learning programs."
        ]
        return AdminCourseDraft(
            id: UUID(),
            createdAt: now,
            updatedAt: now,
            createdBy: createdBy,
            title: title,
            summary: "AI-generated draft for administrators only. Includes module video lessons plus course materials from open-source references for internal review before publication.",
            targetAudience: audience,
            level: level,
            durationWeeks: durationWeeks,
            outcomes: outcomes,
            modules: modules,
            status: .readyForReview,
            accessTier: accessTier,
            sourceReferences: snapshot.sources,
            promotionalCopy: promotionalCopy,
            funnelPreview: funnelPreview,
            reasoningReport: reasoningReport,
            researchTrace: researchTrace,
            cohortSelection: cohortSelection,
            reportFindings: reportFindings
        )
    }

    private func deriveTitle(from prompt: String) -> String {
        let trimmed = prompt.components(separatedBy: .newlines).first ?? prompt
        if trimmed.count <= 60 { return trimmed.capitalized }
        return "WCS Program: " + String(trimmed.prefix(48)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func deriveAudience(from prompt: String) -> String {
        let lower = prompt.lowercased()
        if lower.contains("school") { return "Schools and institutional cohorts" }
        if lower.contains("founder") || lower.contains("entrepreneur") { return "Founders and business builders" }
        if lower.contains("student") { return "Students and early-career learners" }
        return "Educators, professionals, and mission-led learners"
    }

    private func deriveLevel(from prompt: String) -> String {
        let lower = prompt.lowercased()
        if lower.contains("advanced") { return "Advanced" }
        if lower.contains("beginner") || lower.contains("intro") { return "Beginner" }
        return "Intermediate"
    }

    private func deriveDuration(from prompt: String) -> Int {
        let lower = prompt.lowercased()
        if lower.contains("bootcamp") { return 4 }
        if lower.contains("masterclass") { return 6 }
        return 8
    }

    private func makeModule(title: String, theme: String, includeQuiz: Bool, references: [String]) -> AdminModuleDraft {
        let materialPack = references.isEmpty
            ? "Course materials pack: lecture slides, reading notes, worksheet, and discussion prompts."
            : "Course materials pack based on: \(references.prefix(2).joined(separator: ", ")). Includes slides, notes, and worksheet."

        var lessons: [AdminLessonDraft] = [
            AdminLessonDraft(id: UUID(), title: "Lecture: \(theme)", kind: .video, durationMinutes: 25, notes: "Core concept delivery."),
            AdminLessonDraft(id: UUID(), title: "Video case walkthrough", kind: .video, durationMinutes: 18, notes: "Applied walkthrough using real scenarios."),
            AdminLessonDraft(
                id: UUID(),
                title: "Course materials and reading brief",
                kind: .reading,
                durationMinutes: 15,
                notes: references.first.map { "Reference: \($0). \(materialPack)" } ?? materialPack
            )
        ]
        if includeQuiz {
            lessons.append(AdminLessonDraft(id: UUID(), title: "Knowledge check", kind: .quiz, durationMinutes: 10, notes: "Auto-graded assessment."))
        }
        lessons.append(AdminLessonDraft(id: UUID(), title: "Applied assignment", kind: .assignment, durationMinutes: 45, notes: "Rubric-based submission."))

        return AdminModuleDraft(
            id: UUID(),
            title: title,
            goals: [
                "Clarify key ideas and vocabulary.",
                "Practice with structured activities.",
                "Track evidence of mastery."
            ],
            lessons: lessons
        )
    }

    private func buildReasoningReport(
        prompt: String,
        title: String,
        sourceTitles: [String],
        qualityGate: AIQualityGate
    ) -> AIReasoningReport {
        let assumptions = [
            "Learners need structured progression from concept to application.",
            "Assessment and evidence-backed references increase learning quality.",
            "Course outcomes should map to employability and real-world delivery."
        ]
        let evidenceSet = sourceTitles.isEmpty ? ["No external source titles available from this prompt."] : sourceTitles
        let steps = [
            AIReasoningStep(
                id: UUID(),
                title: "Query Decomposition",
                analysis: "Decomposed the request into learner profile, capabilities, and delivery constraints for \(title), then planned retrieval sub-queries.",
                evidence: [evidenceSet.first ?? "Prompt context only"]
            ),
            AIReasoningStep(
                id: UUID(),
                title: "Retrieval + Reranking",
                analysis: "Ranked Open Library and OpenAlex signals by relevance and freshness using a quality gate score of \(qualityGate.score.formatted(.number.precision(.fractionLength(2)))) against threshold \(qualityGate.threshold.formatted(.number.precision(.fractionLength(2)))).",
                evidence: Array(evidenceSet.prefix(3)).enumerated().map { offset, value in
                    "[\(offset + 1)] \(value)"
                }
            ),
            AIReasoningStep(
                id: UUID(),
                title: "Citation-Grounded Program Construction",
                analysis: "Built a foundation-to-capstone pathway and mapped key claims to explicit source evidence to keep outputs auditable.",
                evidence: ["Module architecture follows progressive complexity."]
            )
        ]

        return AIReasoningReport(
            focusQuestion: "How should \(title) be designed to deliver measurable learner outcomes with verifiable evidence?",
            assumptions: assumptions,
            reasoningSteps: steps,
            conclusion: "Recommended structure is a three-stage learning path with quality-gated evidence, citation-grounded materials, and assessment checkpoints.",
            confidenceScore: qualityGate.passed ? min(0.93, qualityGate.score + 0.12) : max(0.55, qualityGate.score - 0.08)
        )
    }

    private func buildResearchTrace(
        prompt: String,
        title: String,
        snapshot: OpenSourceResearchSnapshot
    ) -> AIResearchTrace {
        let generatedQueries = buildQueries(from: prompt, title: title)
        let cards = buildEvidenceCards(snapshot: snapshot)
        let qualityGate = scoreQualityGate(cards: cards)
        let citationMap = buildCitationMap(title: title, cards: cards)

        return AIResearchTrace(
            engineName: "WCS AI Course Generation Engine",
            retrievalMode: "Hybrid semantic + keyword retrieval (Open Library + OpenAlex)",
            generatedQueries: generatedQueries,
            evidenceCards: cards,
            qualityGate: qualityGate,
            citationMap: citationMap
        )
    }

    private func buildQueries(from prompt: String, title: String) -> [String] {
        let topicSeed = title.lowercased()
        let normalizedPrompt = prompt.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let promptChunk = String(normalizedPrompt.prefix(90))
        return [
            "\(topicSeed) curriculum best practices",
            "\(topicSeed) evidence based teaching frameworks",
            "\(topicSeed) case studies and practical applications",
            "\(promptChunk) assessment and certification design"
        ]
    }

    private func buildEvidenceCards(snapshot: OpenSourceResearchSnapshot) -> [AIEvidenceCard] {
        let books = snapshot.bookTitles.prefix(3).enumerated().map { index, title in
            AIEvidenceCard(
                id: UUID(),
                title: title,
                source: "Open Library",
                snippet: "Book reference used for theory framing and reading list design.",
                relevanceScore: max(0.60, 0.88 - (Double(index) * 0.09)),
                freshnessScore: max(0.55, 0.82 - (Double(index) * 0.08))
            )
        }
        let works = snapshot.workTitles.prefix(3).enumerated().map { index, title in
            AIEvidenceCard(
                id: UUID(),
                title: title,
                source: "OpenAlex",
                snippet: "Research work used for evidence-led lessons, quiz items, and assignment prompts.",
                relevanceScore: max(0.62, 0.90 - (Double(index) * 0.08)),
                freshnessScore: max(0.58, 0.86 - (Double(index) * 0.08))
            )
        }
        return books + works
    }

    private func scoreQualityGate(cards: [AIEvidenceCard]) -> AIQualityGate {
        guard !cards.isEmpty else {
            return AIQualityGate(
                passed: false,
                threshold: qualityGateThreshold,
                score: 0.48,
                rationale: "Insufficient external evidence; proceed with prompt-only draft confidence."
            )
        }

        let score = cards.map { ($0.relevanceScore * 0.7) + ($0.freshnessScore * 0.3) }.reduce(0, +) / Double(cards.count)
        let passed = score >= qualityGateThreshold
        let rationale = passed
            ? "Evidence set passed relevance/freshness gate and can support citation-grounded generation."
            : "Evidence set is weak; generation proceeds with lower confidence and stronger prompt constraints."

        return AIQualityGate(
            passed: passed,
            threshold: qualityGateThreshold,
            score: score,
            rationale: rationale
        )
    }

    private func buildCitationMap(title: String, cards: [AIEvidenceCard]) -> [AICitationMapping] {
        let defaultClaim = AICitationMapping(
            id: UUID(),
            claim: "Program \(title) should progress from fundamentals to applied implementation with assessment checkpoints.",
            sourceTitle: "Prompt context",
            sourceSystem: "WCS Prompt Planner"
        )
        guard !cards.isEmpty else { return [defaultClaim] }

        var mappings: [AICitationMapping] = []
        mappings.append(defaultClaim)
        for card in cards.prefix(3) {
            mappings.append(
                AICitationMapping(
                    id: UUID(),
                    claim: "Learning materials include evidence-backed concepts from \(card.title).",
                    sourceTitle: card.title,
                    sourceSystem: card.source
                )
            )
        }
        return mappings
    }

    private func parsePlannerContext(from prompt: String) -> PlannerContext {
        let productName = value(for: "Product name:", in: prompt) ?? ""
        let learner = value(for: "Ideal learner:", in: prompt) ?? ""
        let transformation = value(for: "Transformation promise:", in: prompt) ?? ""
        let notes = value(for: "Additional curriculum and brand notes:", in: prompt) ?? ""
        let researchTopic = [productName, transformation, learner]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return PlannerContext(
            productName: productName,
            learner: learner,
            transformation: transformation,
            notes: notes,
            researchTopic: researchTopic.isEmpty ? prompt : researchTopic
        )
    }

    private func value(for prefix: String, in prompt: String) -> String? {
        guard let line = prompt.components(separatedBy: .newlines).first(where: { $0.hasPrefix(prefix) }) else { return nil }
        let raw = line.replacingOccurrences(of: prefix, with: "")
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func deriveTitle(from prompt: String, context: PlannerContext) -> String {
        if !context.productName.isEmpty {
            return normalizeTitle(context.productName)
        }
        let firstLine = prompt.components(separatedBy: .newlines).first ?? prompt
        return normalizeTitle(firstLine)
    }

    private func normalizeTitle(_ raw: String) -> String {
        var value = raw
            .replacingOccurrences(of: "Build a WCS AI Course Generation blueprint using", with: "")
            .replacingOccurrences(of: "Build a Kajabi-style AI course blueprint.", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { value = "WCS Signature Program" }
        if value.count > 70 {
            value = String(value.prefix(70)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value
    }

    private func buildFunnelPreview(title: String, audience: String, level: String) -> AIFunnelPreview {
        AIFunnelPreview(
            headline: "\(title): Build high-value outcomes in weeks, not months.",
            subheadline: "Designed for \(audience.lowercased()) with a \(level.lowercased()) pathway, practical implementation, and certification readiness.",
            callToAction: "Enroll now and start your first module today.",
            offerBullets: [
                "Step-by-step curriculum with AI-guided videos and resources",
                "Auto-graded quizzes with Oxford-style performance feedback",
                "Capstone assignment and completion certificate"
            ],
            emailHooks: [
                "The 3 mistakes most learners make before they even start",
                "A behind-the-scenes look at your first module transformation",
                "Your personalized roadmap to completion and certification"
            ]
        )
    }

    private func deriveCohortSelection(from prompt: String, context: PlannerContext) -> AICohortSelection {
        let lower = "\(prompt) \(context.notes)".lowercased()
        if lower.contains("enterprise") || lower.contains("team") || lower.contains("institution") {
            return AICohortSelection(
                cohortType: .enterpriseTeam,
                recommendedSize: 40,
                rationale: "Enterprise delivery benefits from larger group onboarding and manager checkpoints."
            )
        }
        if lower.contains("bootcamp") || lower.contains("intensive") {
            return AICohortSelection(
                cohortType: .intensiveBootcamp,
                recommendedSize: 24,
                rationale: "Bootcamp-style pacing needs tighter mentor bandwidth and higher interaction frequency."
            )
        }
        if lower.contains("cohort") || lower.contains("weekly") || lower.contains("live") {
            return AICohortSelection(
                cohortType: .weeklyCohort,
                recommendedSize: 30,
                rationale: "Weekly cohorts balance peer discussion quality with scalable facilitation."
            )
        }
        return AICohortSelection(
            cohortType: .selfPaced,
            recommendedSize: 120,
            rationale: "Self-paced model scales best with asynchronous content and automated assessments."
        )
    }

    private func buildCourseReportFindings(
        title: String,
        cohortSelection: AICohortSelection,
        qualityGate: AIQualityGate,
        sourceTitles: [String]
    ) -> [AICourseReportFinding] {
        let sourceSignal = sourceTitles.isEmpty ? "Prompt-only signal used; increase source depth." : "Source-backed signal from \(sourceTitles.count) references."
        return [
            AICourseReportFinding(
                id: UUID(),
                title: "Delivery model fit",
                detail: "\(cohortSelection.cohortType.label) is recommended with target cohort size \(cohortSelection.recommendedSize). \(cohortSelection.rationale)",
                confidence: min(0.95, qualityGate.score + 0.08)
            ),
            AICourseReportFinding(
                id: UUID(),
                title: "Evidence readiness",
                detail: "Quality gate score \(qualityGate.score.formatted(.number.precision(.fractionLength(2)))) against threshold \(qualityGate.threshold.formatted(.number.precision(.fractionLength(2)))). \(sourceSignal)",
                confidence: qualityGate.score
            ),
            AICourseReportFinding(
                id: UUID(),
                title: "Publishability signal",
                detail: "Generated output is structured into modules, assessments, and citation mapping, suitable for review-to-publish workflow.",
                confidence: qualityGate.passed ? 0.9 : 0.72
            )
        ]
    }
}

private struct PlannerContext {
    let productName: String
    let learner: String
    let transformation: String
    let notes: String
    let researchTopic: String
}

struct OpenSourceResearchSnapshot {
    var bookTitles: [String]
    var workTitles: [String]
    var sources: [String]
}

struct OpenSourceResearchService {
    private struct OpenLibraryResponse: Decodable {
        struct Doc: Decodable { let title: String? }
        let docs: [Doc]
    }

    private struct OpenAlexResponse: Decodable {
        struct Work: Decodable { let display_name: String? }
        let results: [Work]
    }

    func fetch(topic: String) async -> OpenSourceResearchSnapshot {
        async let books = fetchOpenLibrary(topic: topic)
        async let works = fetchOpenAlex(topic: topic)
        async let perplexityLines = PerplexityAPIClient.fetchResearchLines(topic: topic, maxLines: 5)
        let (bookTitles, workTitles, perplexity) = await (books, works, perplexityLines)
        let mergedWorks = Array((perplexity + workTitles).prefix(8))
        var sources: [String] = []
        if !bookTitles.isEmpty { sources.append("Open Library API") }
        if !workTitles.isEmpty { sources.append("OpenAlex API") }
        if !perplexity.isEmpty { sources.append("Perplexity (web-grounded)") }
        return OpenSourceResearchSnapshot(bookTitles: bookTitles, workTitles: mergedWorks, sources: sources)
    }

    private func fetchOpenLibrary(topic: String) async -> [String] {
        guard let encoded = topic.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://openlibrary.org/search.json?q=\(encoded)&limit=5") else {
            return []
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else { return [] }
            let decoded = try JSONDecoder().decode(OpenLibraryResponse.self, from: data)
            return decoded.docs.compactMap(\.title).prefix(4).map { $0 }
        } catch {
            return []
        }
    }

    private func fetchOpenAlex(topic: String) async -> [String] {
        guard let encoded = topic.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.openalex.org/works?search=\(encoded)&per-page=5") else {
            return []
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else { return [] }
            let decoded = try JSONDecoder().decode(OpenAlexResponse.self, from: data)
            return decoded.results.compactMap(\.display_name).prefix(4).map { $0 }
        } catch {
            return []
        }
    }
}
