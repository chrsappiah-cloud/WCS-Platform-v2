//
//  AdminCourseCreatorView.swift
//  WCS-Platform
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

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
        .task { await viewModel.loadLessonVideoRenderJobs() }
        .task { await viewModel.startRealtimeVideoPolling() }
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

    @ViewBuilder
    private var lessonVideoJobAuditPanel: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Lesson video render audit (Supabase)")
                .font(.headline.weight(.semibold))

            if !LessonVideoGenerationSettings.isRemoteTextToVideoEnabled {
                Text("Set WCSLessonTextToVideoEndpoint to enable remote generation and job-list URL derivation.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if !LessonVideoGenerationSettings.isLessonVideoJobHistoryEnabled {
                Text(
                    "Deploy Edge `wcs-lesson-video-jobs`, set secret `WCS_JOB_LIST_SECRET` on the function, and set WCSLessonVideoJobListSecret (same value) in the app. Run `supabase db push` for table `wcs_lesson_video_render_jobs`."
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            } else {
                HStack {
                    Button("Refresh job list") {
                        Task { await viewModel.loadLessonVideoRenderJobs() }
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    Spacer()
                }

                if let err = viewModel.lessonVideoJobsLoadError {
                    Text(err)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                if viewModel.lessonVideoRenderJobs.isEmpty && viewModel.lessonVideoJobsLoadError == nil {
                    Text("No jobs yet — generate module videos or invoke the Edge function.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ForEach(viewModel.lessonVideoRenderJobs) { job in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(job.normalizedStatusLabel) · \(job.provider) · lesson \(job.lessonId.prefix(8))…")
                            .font(.caption.weight(.semibold))
                        if let mode = job.pipelineMode {
                            Text("Pipeline: \(mode)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let at = job.createdAt {
                            Text(at)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.tertiary)
                        }
                        if let urlString = job.playbackUrl, let url = URL(string: urlString) {
                            Link("Open playback URL", destination: url)
                                .font(.caption2)
                        }
                        if let excerpt = job.generationPromptExcerpt {
                            Text(excerpt)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                        }
                        if let err = job.errorMessage {
                            Text(err)
                                .font(.caption2)
                                .foregroundStyle(.red)
                                .lineLimit(4)
                        }
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .wcsInsetPanel()
    }

    private var console: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                Text("WCS AI Course Generation Studio")
                    .wcsSectionTitle()

                lessonVideoJobAuditPanel

                HStack(spacing: DesignTokens.Spacing.sm) {
                    Button("Save these settings as defaults") {
                        viewModel.saveCurrentAsDefaultConfiguration()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DesignTokens.brand)

                    Button("Load defaults") {
                        viewModel.applySavedConfigurationIfAvailable()
                    }
                    .buttonStyle(.bordered)

                    Button("Reset defaults", role: .destructive) {
                        viewModel.resetSavedConfiguration()
                    }
                    .buttonStyle(.bordered)
                }
                .font(.caption)

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

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Manual backup authoring (upload fallback)")
                        .font(.headline.weight(.semibold))
                    Text("Use this when automated generation is unavailable. Add manual video links, course materials, quizzes, and assignments as a publishable backup draft.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    TextField("Manual course title", text: $viewModel.manualCourseTitle)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled(true)
                        .accessibilityIdentifier("manualCourseTitleField")
                    TextField("Manual summary", text: $viewModel.manualSummary)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled(true)
                        .accessibilityIdentifier("manualSummaryField")
                    TextField("Module title", text: $viewModel.manualModuleTitle)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled(true)
                        .accessibilityIdentifier("manualModuleTitleField")
                    TextField("Video lesson title", text: $viewModel.manualVideoTitle)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled(true)
                        .accessibilityIdentifier("manualVideoTitleField")
                    TextField("Video URL (HTTPS)", text: $viewModel.manualVideoURL)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .accessibilityIdentifier("manualVideoURLField")
                    TextField("Reading lesson title", text: $viewModel.manualReadingTitle)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled(true)
                        .accessibilityIdentifier("manualReadingTitleField")
                    TextField("Quiz lesson title", text: $viewModel.manualQuizTitle)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled(true)
                        .accessibilityIdentifier("manualQuizTitleField")
                    TextField("Assignment lesson title", text: $viewModel.manualAssignmentTitle)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled(true)
                        .accessibilityIdentifier("manualAssignmentTitleField")

                    Text("Reading material")
                        .font(.caption.weight(.semibold))
                    TextEditor(text: $viewModel.manualReadingMaterial)
                        .frame(minHeight: 80)
                        .autocorrectionDisabled(true)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityIdentifier("manualReadingMaterialEditor")

                    Text("Quiz prompts/questions")
                        .font(.caption.weight(.semibold))
                    TextEditor(text: $viewModel.manualQuizPrompt)
                        .frame(minHeight: 70)
                        .autocorrectionDisabled(true)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityIdentifier("manualQuizPromptEditor")

                    Text("Assignment brief")
                        .font(.caption.weight(.semibold))
                    TextEditor(text: $viewModel.manualAssignmentBrief)
                        .frame(minHeight: 80)
                        .autocorrectionDisabled(true)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityIdentifier("manualAssignmentBriefEditor")

                    Button {
                        Task { await viewModel.createManualBackupDraft(createdBy: appViewModel.user?.email ?? "admin@wcs") }
                    } label: {
                        Label("Create manual backup draft", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(!viewModel.canCreateManualBackup || viewModel.isGenerating)
                    .accessibilityIdentifier("createManualBackupDraftButton")
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
                            pipelineStatusText: viewModel.pipelineStatusByDraftID[draft.id],
                            hasPlannedStoryboard: viewModel.plannedStoryboardByDraftID[draft.id] != nil,
                            isPipelineBusy: viewModel.pipelineBusyDraftIDs.contains(draft.id),
                            localComposedVideoURL: viewModel.localComposedVideoByDraftID[draft.id],
                            localImageSequenceClipURL: viewModel.localImageSequenceClipByDraftID[draft.id],
                            localImageSequencePreviewURL: viewModel.localImageSequencePreviewByDraftID[draft.id],
                            imageSequenceSettings: viewModel.imageSequenceSettingsByDraftID[draft.id] ?? .default,
                            onPublish: {
                            Task { await viewModel.publish(draft.id) }
                            },
                            onRegenerateVideos: { clearCache in
                                Task { await viewModel.regenerateVideos(for: draft.id, clearCache: clearCache) }
                            },
                            onPlanStoryboard: {
                                Task { await viewModel.planStoryboard(for: draft.id) }
                            },
                            onRenderScene: {
                                Task { await viewModel.renderFirstPlannedScene(for: draft.id) }
                            },
                            onPreviewScene: {
                                Task { await viewModel.previewFirstPlannedScene(for: draft.id) }
                            },
                            onComposeLesson: {
                                Task { await viewModel.composePlannedLesson(for: draft.id) }
                            },
                            onUpdateImageSequenceSettings: { settings in
                                viewModel.updateImageSequenceSettings(for: draft.id, settings: settings)
                            },
                            onSaveManualLessonVideo: { moduleId, lessonId, url, source in
                                Task {
                                    await viewModel.saveManualLessonVideoBackup(
                                        draftID: draft.id,
                                        moduleID: moduleId,
                                        lessonID: lessonId,
                                        url: url,
                                        externalVideoSource: source
                                    )
                                }
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

private struct ManualLessonVideoBackupRow: View {
    let moduleId: UUID
    let lesson: AdminLessonDraft
    let onSave: (UUID, UUID, String, ExternalLessonVideoSource) -> Void
    @State private var urlText = ""
    @State private var externalSource: ExternalLessonVideoSource = .manual
    @State private var showFileImporter = false
    @State private var lastProbe: ManualVideoFileProbe?
    @State private var probeMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(lesson.title)
                .font(.caption2.weight(.semibold))
            TextField("https://… (MP4, HLS, signed URL)", text: $urlText)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(.caption)
            Picker("Prepared with", selection: $externalSource) {
                ForEach(ExternalLessonVideoSource.allCases) { src in
                    Text(src.displayLabel).tag(src)
                }
            }
            .pickerStyle(.menu)
            .font(.caption2)

            Button("Probe local export (validation only)") {
                showFileImporter = true
            }
            .buttonStyle(.bordered)
            .font(.caption2)

            if let probe = lastProbe {
                Text(
                    "\(probe.fileName) · \(ByteCountFormatter.string(fromByteCount: probe.fileSizeBytes, countStyle: .file)) · \(formatDuration(probe.durationSeconds)) · \(probe.pixelWidth)×\(probe.pixelHeight)"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            if let probeMessage {
                Text(probeMessage)
                    .font(.caption2)
                    .foregroundStyle(lastProbe == nil ? Color.red : Color.secondary)
            }

            Text("Learners stream from the HTTPS URL. Host the exported file on your CDN or storage, then paste the public or signed link here.")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack(spacing: 8) {
                Button("Save backup URL") {
                    onSave(moduleId, lesson.id, urlText, externalSource)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .font(.caption2)
                Button("Clear backup") {
                    urlText = ""
                    lastProbe = nil
                    probeMessage = nil
                    onSave(moduleId, lesson.id, "", .manual)
                }
                .buttonStyle(.bordered)
                .font(.caption2)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.movie, .video, .mpeg4Movie, .quickTimeMovie],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .task(id: "\(lesson.id.uuidString)|\(lesson.notes)") {
            urlText = LessonManualVideoBackup.extractHTTPSURL(from: lesson.notes) ?? ""
            externalSource = LessonManualVideoBackup.extractExternalSource(from: lesson.notes) ?? .manual
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        lastProbe = nil
        probeMessage = nil
        switch result {
        case .failure(let error):
            probeMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else {
                probeMessage = "No file selected."
                return
            }
            Task {
                let ok = url.startAccessingSecurityScopedResource()
                defer {
                    if ok { url.stopAccessingSecurityScopedResource() }
                }
                guard ok else {
                    await MainActor.run { probeMessage = "Could not access the selected file." }
                    return
                }
                do {
                    let probe = try await ManualVideoFileValidator.probe(fileURL: url)
                    await MainActor.run {
                        lastProbe = probe
                        probeMessage = "Ready for upload — copy to your host and paste the HTTPS URL above."
                    }
                } catch {
                    await MainActor.run {
                        probeMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    }
                }
            }
        }
    }
}

private struct DraftCard: View {
    let draft: AdminCourseDraft
    let videoStatus: AdminCourseCreatorViewModel.DraftVideoStatus?
    let generatedAssets: [GeneratedVideoAsset]
    let pipelineStatusText: String?
    let hasPlannedStoryboard: Bool
    let isPipelineBusy: Bool
    let localComposedVideoURL: URL?
    let localImageSequenceClipURL: URL?
    let localImageSequencePreviewURL: URL?
    let imageSequenceSettings: ImageSequenceRenderSettings
    let onPublish: () -> Void
    let onRegenerateVideos: (_ clearCache: Bool) -> Void
    let onPlanStoryboard: () -> Void
    let onRenderScene: () -> Void
    let onPreviewScene: () -> Void
    let onComposeLesson: () -> Void
    let onUpdateImageSequenceSettings: (ImageSequenceRenderSettings) -> Void
    let onSaveManualLessonVideo: (_ moduleId: UUID, _ lessonId: UUID, _ url: String, _ source: ExternalLessonVideoSource) -> Void
    @State private var showingRegenerateConfirmation = false
    @State private var localImageSettings: ImageSequenceRenderSettings = .default

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

                VStack(alignment: .leading, spacing: 6) {
                    Text("Scene pipeline controls")
                        .font(.caption.weight(.semibold))
                    if let pipelineStatusText {
                        Text(pipelineStatusText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Button("Plan storyboard") {
                            onPlanStoryboard()
                        }
                        .buttonStyle(.bordered)
                        .font(.caption2)
                        .disabled(isPipelineBusy)

                        Button("Render first scene") {
                            onRenderScene()
                        }
                        .buttonStyle(.bordered)
                        .font(.caption2)
                        .disabled(isPipelineBusy || !hasPlannedStoryboard)

                        Button("Preview frame") {
                            onPreviewScene()
                        }
                        .buttonStyle(.bordered)
                        .font(.caption2)
                        .disabled(isPipelineBusy || !hasPlannedStoryboard)

                        Button("Compose lesson") {
                            onComposeLesson()
                        }
                        .buttonStyle(.bordered)
                        .font(.caption2)
                        .disabled(isPipelineBusy)
                    }
                    HStack(spacing: 8) {
                        Picker("Resolution", selection: Binding(
                            get: { localImageSettings.resolution },
                            set: { newValue in
                                localImageSettings.resolution = newValue
                                onUpdateImageSequenceSettings(localImageSettings)
                            }
                        )) {
                            ForEach(ImageSequenceResolutionPreset.allCases) { preset in
                                Text(preset.label).tag(preset)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.caption2)

                        Picker("Diagram", selection: Binding(
                            get: { localImageSettings.diagramStyle },
                            set: { newValue in
                                localImageSettings.diagramStyle = newValue
                                onUpdateImageSequenceSettings(localImageSettings)
                            }
                        )) {
                            ForEach(DiagramOverlayStyle.allCases) { style in
                                Text(style.label).tag(style)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.caption2)
                    }
                    HStack(spacing: 8) {
                        Stepper("FPS \(localImageSettings.fps)", value: Binding(
                            get: { Int(localImageSettings.fps) },
                            set: { newValue in
                                localImageSettings.fps = Int32(max(12, min(60, newValue)))
                                onUpdateImageSequenceSettings(localImageSettings)
                            }
                        ), in: 12...60, step: 6)
                        .font(.caption2)

                        Slider(value: Binding(
                            get: { localImageSettings.animationIntensity },
                            set: { newValue in
                                localImageSettings.animationIntensity = newValue
                                onUpdateImageSequenceSettings(localImageSettings)
                            }
                        ), in: 0.2...2.0)
                        Text("Motion \(String(format: "%.1f", localImageSettings.animationIntensity))x")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let localComposedVideoURL {
                        Link("Open local composed video", destination: localComposedVideoURL)
                            .font(.caption2)
                    }
                    if let localImageSequenceClipURL {
                        Link("Open local image-sequence clip", destination: localImageSequenceClipURL)
                            .font(.caption2)
                    }
                    if let localImageSequencePreviewURL {
                        Link("Open preview frame", destination: localImageSequencePreviewURL)
                            .font(.caption2)
                    }
                }
            }

            DisclosureGroup {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text(
                        "Paste an HTTPS playback URL per video or live lesson (exports from Mootion, Invideo AI, or any host). This overrides AI-generated URLs for learners when a backup is set. Use “Probe local export” to validate a file before you upload it to your CDN or Supabase Storage."
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    ForEach(draft.modules) { module in
                        let videoLessons = module.lessons.filter { $0.kind == .video || $0.kind == .live }
                        if !videoLessons.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(module.title)
                                    .font(.caption.weight(.semibold))
                                ForEach(videoLessons) { lesson in
                                    ManualLessonVideoBackupRow(
                                        moduleId: module.id,
                                        lesson: lesson,
                                        onSave: onSaveManualLessonVideo
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            } label: {
                Text("Manual lesson video backups (per module)")
                    .font(.caption.weight(.semibold))
            }

            if !generatedAssets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Generated module videos (real-time)")
                        .font(.caption.weight(.semibold))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(generatedAssets.sorted(by: { $0.generatedAt > $1.generatedAt }), id: \.lessonId) { asset in
                                VStack(alignment: .leading, spacing: 6) {
                                    if let videoID = youtubeVideoID(from: asset.playbackURL) {
                                        YouTubeEmbedWebView(videoID: videoID)
                                            .frame(width: 220, height: 124)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    } else if let videoID = youtubeVideoID(from: asset.youtubeCompanionURL) {
                                        YouTubeEmbedWebView(videoID: videoID)
                                            .frame(width: 220, height: 124)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    } else if let playback = URL(string: asset.playbackURL),
                                              LessonVideoPlaybackPolicy.isNativeAVPlayerHTTPSURL(playback) {
                                        AdminInlineAVVideoPreview(
                                            url: playback,
                                            courseId: draft.id,
                                            moduleId: moduleId(containingLessonId: asset.lessonId),
                                            lessonId: asset.lessonId
                                        )
                                        .frame(width: 220, height: 124)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    } else {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color(.tertiarySystemFill))
                                            .frame(width: 220, height: 124)
                                            .overlay {
                                                Image(systemName: "video.fill")
                                                    .font(.title2)
                                                    .foregroundStyle(.secondary)
                                            }
                                    }

                                    Text(asset.title)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(2)
                                        .frame(width: 220, alignment: .leading)
                                    if let kit = asset.motionTextToVideoKit {
                                        Text("Kit: \(kit.enginePreset) · \(kit.aspectRatio)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .frame(width: 220, alignment: .leading)
                                    }
                                    if let playbackURL = URL(string: asset.playbackURL) {
                                        Link("Open playback URL", destination: playbackURL)
                                            .font(.caption2)
                                    }
                                    if let kit = asset.motionTextToVideoKit {
                                        Button("Copy kit JSON") {
                                            UIPasteboard.general.string = exportJSON(for: kit)
                                        }
                                        .buttonStyle(.bordered)
                                        .font(.caption2)
                                    }
                                }
                                .frame(width: 220, alignment: .leading)
                            }
                        }
                    }
                }
            }

            if let newestAsset = generatedAssets.sorted(by: { $0.generatedAt > $1.generatedAt }).first,
               let kit = newestAsset.motionTextToVideoKit {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Text-to-video kit (Motion AI style)")
                        .font(.caption.weight(.semibold))
                    Text("Preset: \(kit.enginePreset) · Export: \(kit.exportPreset)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(kit.shotPrompt)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                    Text("Scene beats")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(Array(kit.sceneBeats.prefix(4).enumerated()), id: \.offset) { _, beat in
                        Text("• \(beat)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 4)
            }

            AdminDraftCompanionMediaStrip(draft: draft)

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
        .onAppear {
            localImageSettings = imageSequenceSettings
        }
        .onChange(of: imageSequenceSettings) { _, newValue in
            localImageSettings = newValue
        }
    }

    private func moduleId(containingLessonId lessonId: UUID) -> UUID {
        draft.modules.first(where: { $0.lessons.contains(where: { $0.id == lessonId }) })?.id ?? lessonId
    }

    private func youtubeVideoID(from rawURL: String?) -> String? {
        guard let rawURL, let url = URL(string: rawURL) else { return nil }
        let host = (url.host ?? "").lowercased()
        if host.contains("youtu.be") {
            let id = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return id.count == 11 ? id : nil
        }
        guard host.contains("youtube.com"),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }
        if let id = components.queryItems?.first(where: { $0.name == "v" })?.value, id.count == 11 {
            return id
        }
        if components.path.contains("/embed/"), let last = components.path.split(separator: "/").last {
            let id = String(last)
            return id.count == 11 ? id : nil
        }
        return nil
    }

    private func exportJSON(for kit: MotionTextToVideoKit) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(kit), let text = String(data: data, encoding: .utf8) {
            return text
        }
        return """
        {
          "enginePreset": "\(kit.enginePreset)",
          "targetDurationSeconds": \(kit.targetDurationSeconds)
        }
        """
    }
}

/// Live YouTube Data API preview for administrators: draft module/lesson script → `search.list` → embeds.
private struct AdminDraftCompanionMediaStrip: View {
    let draft: AdminCourseDraft
    @State private var results: [AdminLessonVideoDiscoveryResult] = []
    @State private var loadError: String?
    @State private var didAttemptLoad = false

    var body: some View {
        Group {
            if YouTubeSearchAPIClient.resolveAPIKey() == nil {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("External API · YouTube companion (Data API)")
                        .font(.caption.weight(.semibold))
                    Text(
                        "Maps each draft video/live lesson to a grounded search query (title + notes), then embeds top hits. Capped to four lessons per draft to protect quota."
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    if let loadError {
                        Text(loadError)
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }

                    ForEach(results) { bundle in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(bundle.scriptLine.lessonTitle)
                                .font(.caption.weight(.semibold))
                            Text(bundle.scriptLine.youTubeSearchQuery)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(bundle.snippets) { snippet in
                                        YouTubeEmbedWebView(videoID: snippet.videoID)
                                            .frame(width: 220, height: 124)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, DesignTokens.Spacing.xs)
                .task {
                    guard !didAttemptLoad else { return }
                    didAttemptLoad = true
                    await loadCompanion()
                }
            }
        }
    }

    private func loadCompanion() async {
        let lines = Array(ModuleVideoDiscoveryPipeline.adminScriptLines(from: draft).prefix(4))
        guard !lines.isEmpty else { return }
        do {
            results = try await ModuleVideoDiscoveryPipeline.resolveAdminDraftVideos(
                scriptLines: lines,
                maxResultsPerLesson: 2
            )
            loadError = nil
        } catch {
            results = []
            loadError = error.localizedDescription
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
