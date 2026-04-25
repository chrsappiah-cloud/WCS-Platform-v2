//
//  AdminCourseCreatorView.swift
//  WCS-Platform
//

import SwiftUI

struct AdminCourseCreatorView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = AdminCourseCreatorViewModel()

    var body: some View {
        Group {
            if !viewModel.isUnlocked {
                lockedGate
            } else {
                console
            }
        }
        .wcsGroupedScreen()
        .navigationTitle("WCS AI Course Generation")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .task { await viewModel.loadDrafts() }
        .onReceive(NotificationCenter.default.publisher(for: .wcsAdminDraftsDidChange)) { _ in
            guard !AppEnvironment.debugSafeMode else { return }
            Task { await viewModel.loadDrafts() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .wcsLearningStateDidChange)) { _ in
            Task { await viewModel.refreshVideoStatuses() }
        }
    }

    private var lockedGate: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 54))
                .foregroundStyle(DesignTokens.brand)

            Text("Administrator Access")
                .font(.title2.weight(.bold))

            Text("This AI course authoring workspace is private and not accessible to students.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            SecureField("Admin access code", text: $viewModel.accessCodeInput)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .simulatorStableTextSelection()
                .padding(.horizontal, 24)

            Button("Unlock Studio") {
                viewModel.unlock()
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignTokens.brandAccent)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var console: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                Text("WCS AI Course Generation Studio")
                    .wcsSectionTitle()

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Blueprint templates")
                        .font(.headline.weight(.semibold))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            ForEach(KajabiBlueprintTemplate.allCases) { template in
                                Button(template.rawValue) {
                                    viewModel.applyTemplate(template)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .wcsInsetPanel()

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Offer configuration")
                        .font(.headline.weight(.semibold))
                    TextField("Product name", text: $viewModel.productName)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled(AppEnvironment.simulatorStabilityMode)
                    TextField("Ideal learner avatar", text: $viewModel.idealLearner)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled(AppEnvironment.simulatorStabilityMode)
                    TextField("Transformation promise", text: $viewModel.transformation)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled(AppEnvironment.simulatorStabilityMode)
                    TextField("Offer stack (bonuses, cohort, certificate, etc.)", text: $viewModel.offerStack)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled(AppEnvironment.simulatorStabilityMode)
                    TextField("Launch angle and positioning", text: $viewModel.launchAngle)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled(AppEnvironment.simulatorStabilityMode)
                    Picker("Cohort delivery", selection: $viewModel.selectedCohortType) {
                        ForEach(AICohortType.allCases) { cohortType in
                            Text(cohortType.label).tag(cohortType)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextField("Preferred cohort size", text: $viewModel.preferredCohortSize)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled(true)
                }
                .wcsInsetPanel()

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Curriculum + production notes")
                        .font(.headline.weight(.semibold))

                    Picker("Access model", selection: $viewModel.selectedAccessTier) {
                        ForEach(AdminCourseAccessTier.allCases) { tier in
                            Text(tier.label).tag(tier)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextEditor(text: $viewModel.prompt)
                        .frame(minHeight: 120)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(AppEnvironment.simulatorStabilityMode ? .never : .sentences)
                        .simulatorStableTextSelection()
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button {
                        Task { await viewModel.generate(createdBy: appViewModel.user?.email ?? "admin@wcs") }
                    } label: {
                        if viewModel.isGenerating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Label("Generate WCS Draft", systemImage: "sparkles")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DesignTokens.brandAccent)
                    .disabled(!viewModel.canGenerate || viewModel.isGenerating)

                    Text("WCS AI Course Generation uses retrieval planning, reranking, and citation-grounded synthesis with Open Library + OpenAlex evidence.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .wcsInsetPanel()

                HStack {
                    Text("Drafts")
                        .wcsSectionTitle()
                    Spacer()
                    Button(role: .destructive) {
                        Task { await viewModel.clearAll() }
                    } label: {
                        Text("Clear")
                    }
                    .font(.caption)
                }

                if viewModel.drafts.isEmpty {
                    ContentUnavailableView(
                        "No drafts yet",
                        systemImage: "doc.badge.plus",
                        description: Text("Generate your first private AI course draft.")
                    )
                } else {
                    ForEach(viewModel.drafts) { draft in
                        DraftCard(
                            draft: draft,
                            videoStatus: viewModel.videoStatusByDraftID[draft.id],
                            generatedAssets: viewModel.generatedAssetsByDraftID[draft.id] ?? [],
                            onPublish: {
                            Task { await viewModel.publish(draft.id) }
                            },
                            onRegenerateVideos: { clearCache in
                                Task { await viewModel.regenerateVideos(for: draft.id, clearCache: clearCache) }
                            }
                        )
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
    }
}

private struct DraftCard: View {
    let draft: AdminCourseDraft
    let videoStatus: AdminCourseCreatorViewModel.DraftVideoStatus?
    let generatedAssets: [GeneratedVideoAsset]
    let onPublish: () -> Void
    let onRegenerateVideos: (_ clearCache: Bool) -> Void
    @State private var showingRegenerateConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text(draft.title)
                    .font(.headline)
                Spacer()
                Text(draft.accessTier.label)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemFill), in: Capsule())
                Text(draft.status.rawValue.capitalized)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }

            Text(draft.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Audience: \(draft.targetAudience) · Level: \(draft.level) · \(draft.durationWeeks) weeks")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Modules: \(draft.modules.count) · Findings: \(draft.reportFindings.count)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let status = videoStatus, status.totalVideoLessons > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Video generation")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text(status.isGenerating ? "Generating…" : (status.generatedVideoLessons == status.totalVideoLessons ? "Ready" : "Queued"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(status.isGenerating ? .orange : .secondary)
                    }
                    Text("Generated \(status.generatedVideoLessons)/\(status.totalVideoLessons) lesson video assets.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let latest = status.latestGeneratedAt {
                        Text("Last recorded: \(latest.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button("Resume generation") {
                            onRegenerateVideos(false)
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)

                        Button("Regenerate fresh") {
                            showingRegenerateConfirmation = true
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                }
                Text("Debug assets: \(generatedAssets.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if draft.status != .published {
                Button("Publish to learner catalog") {
                    onPublish()
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.brand)
            }
        }
        .wcsInsetPanel()
        .alert("Regenerate all videos?", isPresented: $showingRegenerateConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Regenerate", role: .destructive) {
                onRegenerateVideos(true)
            }
        } message: {
            Text("This clears archived video assets for this draft and generates fresh recordings in real time.")
        }
    }
}

private struct FunnelPreviewDetailView: View {
    let draft: AdminCourseDraft

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                Text(draft.title)
                    .font(.title3.weight(.bold))

                if let funnel = draft.funnelPreview {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Landing headline")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(funnel.headline)
                            .font(.headline)
                        Text(funnel.subheadline)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("CTA: \(funnel.callToAction)")
                            .font(.subheadline.weight(.semibold))
                    }
                    .wcsInsetPanel()

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Offer bullets")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(Array(funnel.offerBullets.enumerated()), id: \.offset) { _, bullet in
                            Text("• \(bullet)")
                                .font(.subheadline)
                        }
                    }
                    .wcsInsetPanel()

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Email hooks")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(Array(funnel.emailHooks.enumerated()), id: \.offset) { _, hook in
                            Text("• \(hook)")
                                .font(.subheadline)
                        }
                    }
                    .wcsInsetPanel()
                } else {
                    ContentUnavailableView(
                        "No funnel preview",
                        systemImage: "megaphone",
                        description: Text("Generate a new draft to get landing copy and launch hooks.")
                    )
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .wcsGroupedScreen()
        .navigationTitle("Funnel Preview")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ReasoningDetailView: View {
    let draft: AdminCourseDraft

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                Text(draft.title)
                    .font(.title3.weight(.bold))

                if let reasoning = draft.reasoningReport {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        HStack {
                            Text("Focus question")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            ConfidenceChip(score: reasoning.confidenceScore)
                        }
                        Text(reasoning.focusQuestion)
                            .font(.body)
                    }
                    .wcsInsetPanel()

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Assumptions")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(Array(reasoning.assumptions.enumerated()), id: \.offset) { _, assumption in
                            Text("• \(assumption)")
                                .font(.subheadline)
                        }
                    }
                    .wcsInsetPanel()

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Reasoning steps")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(reasoning.reasoningSteps) { step in
                            AnswerStepRow(step: step)
                        }
                    }
                    .wcsInsetPanel()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Conclusion")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(reasoning.conclusion)
                            .font(.subheadline)
                    }
                    .wcsInsetPanel()

                    if let research = draft.researchTrace {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text("Research trace")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(research.engineName)
                                .font(.subheadline.weight(.semibold))
                            Text(research.retrievalMode)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !research.evidenceCards.isEmpty {
                                Text("Top evidence")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(research.evidenceCards.prefix(3)) { card in
                                    EvidenceCardMiniRow(card: card)
                                }
                            }
                            if !research.generatedQueries.isEmpty {
                                Text("Generated queries")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(Array(research.generatedQueries.enumerated()), id: \.offset) { _, query in
                                    Text("• \(query)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if !research.citationMap.isEmpty {
                                Text("Citation map")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(Array(research.citationMap.prefix(4).enumerated()), id: \.element.id) { index, mapping in
                                    Text("[\(index + 1)] \(mapping.sourceTitle) · \(mapping.sourceSystem)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .wcsInsetPanel()
                    }
                } else {
                    ContentUnavailableView(
                        "No reasoning report",
                        systemImage: "brain",
                        description: Text("This draft does not include structured reasoning data.")
                    )
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .wcsGroupedScreen()
        .navigationTitle("Reasoning")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ConfidenceChip: View {
    let score: Double

    var body: some View {
        Text("Confidence \(score * 100, specifier: "%.0f%%")")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((score >= 0.7 ? Color.green.opacity(0.15) : Color.orange.opacity(0.15)), in: Capsule())
            .foregroundStyle(score >= 0.7 ? Color.green : Color.orange)
    }
}

private struct AnswerStepRow: View {
    let step: AIReasoningStep

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(step.title)
                .font(.caption.weight(.semibold))
            Text(step.analysis)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct EvidenceCardMiniRow: View {
    let card: AIEvidenceCard

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(card.title)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
            Text("\(card.source) · relevance \(card.relevanceScore * 100, specifier: "%.0f%%")")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct BulletListView: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Text(verbatim: "• \(item)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AdminCourseCreatorView()
            .environmentObject(AppViewModel())
    }
}
