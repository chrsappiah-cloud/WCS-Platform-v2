//
//  CourseDetailView.swift
//  WCS-Platform
//

import SwiftUI

struct CourseDetailView: View {
    let courseId: UUID
    @StateObject private var viewModel: CourseDetailViewModel

    init(courseId: UUID) {
        self.courseId = courseId
        _viewModel = StateObject(wrappedValue: CourseDetailViewModel(courseId: courseId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.course == nil {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(DesignTokens.brandAccent)
                    Text("Loading program…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.lastError {
                ContentUnavailableView(
                    "Something went wrong",
                    systemImage: "exclamationmark.triangle.fill",
                    description: Text(error.localizedDescription)
                )
            } else if let course = viewModel.course {
                courseScroll(course)
            } else {
                ContentUnavailableView(
                    "Program unavailable",
                    systemImage: "book.closed.fill",
                    description: Text("This program isn’t in the catalog.")
                )
            }
        }
        .wcsGroupedScreen()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let t = viewModel.course?.title {
                    Text(t)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                }
            }
        }
        .task {
            await viewModel.loadCourse()
        }
        .onReceive(NotificationCenter.default.publisher(for: .wcsLearningStateDidChange)) { _ in
            Task { await viewModel.loadCourse() }
        }
    }

    @ViewBuilder
    private func courseScroll(_ course: Course) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero(course)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    metaBlock(course)
                    courseAtAGlance(course)

                    openScholarshipBlock(course)

                    enrollmentBlock(course)

                    if course.isEnrolled {
                        progressBlock(course)
                    }

                    phaseFourCompanionVideoBlock(course)

                    Text("Syllabus")
                        .wcsSectionTitle()
                        .padding(.top, DesignTokens.Spacing.xs)

                    ForEach(course.modules.sorted(by: { $0.order < $1.order })) { module in
                        DisclosureGroup {
                            VStack(spacing: 0) {
                                ForEach(Array(module.lessons.enumerated()), id: \.element.id) { index, lesson in
                                    NavigationLink {
                                        lessonDestination(course: course, module: module, lesson: lesson)
                                    } label: {
                                        LessonRowView(lesson: lesson)
                                    }
                                    if index < module.lessons.count - 1 {
                                        Divider()
                                            .padding(.leading, 52)
                                    }
                                }
                            }
                            .padding(.vertical, DesignTokens.Spacing.xs)
                        } label: {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                Text(module.title)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                if let d = module.description {
                                    Text(d)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DesignTokens.Spacing.md)
                            .background(DesignTokens.brandMuted, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                        }
                        .tint(DesignTokens.brandAccent)
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }
        }
    }

    @ViewBuilder
    private func hero(_ course: Course) -> some View {
        let url = URL(string: course.coverURL ?? course.thumbnailURL)
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [DesignTokens.brand, DesignTokens.brand.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay { ProgressView().tint(.white) }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Rectangle()
                        .fill(DesignTokens.brand.opacity(0.5))
                @unknown default:
                    EmptyView()
                }
            }
            .frame(height: 240)
            .clipped()

            DesignTokens.heroGradient
                .frame(height: 240)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                if let org = course.organizationName {
                    Text(org.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .tracking(0.8)
                }
                Text(course.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DesignTokens.Spacing.lg)
        }
    }

    @ViewBuilder
    private func metaBlock(_ course: Course) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(course.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: DesignTokens.Spacing.sm)], spacing: DesignTokens.Spacing.sm) {
                if let level = course.level {
                    DetailPill(title: "Level", value: level, icon: "stairs")
                }
                if let effort = course.effortDescription {
                    DetailPill(title: "Effort", value: effort, icon: "clock")
                }
                DetailPill(title: "Language", value: course.displayLanguages, icon: "globe")
                if let rating = course.rating {
                    DetailPill(title: "Rating", value: String(format: "%.1f ★ · %d reviews", rating, course.reviewCount), icon: "star.fill")
                }
            }
        }
        .wcsInsetPanel()
    }

    @ViewBuilder
    private func courseAtAGlance(_ course: Course) -> some View {
        let allLessons = course.modules.flatMap(\.lessons)
        let quizCount = allLessons.filter { $0.type == .quiz }.count
        let assignmentCount = allLessons.filter { $0.type == .assignment }.count
        let videoCount = allLessons.filter { $0.type == .video }.count
        let outcomes = extractOutcomes(from: course.description)

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Course at a glance")
                .font(.headline.weight(.semibold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: DesignTokens.Spacing.sm)], spacing: DesignTokens.Spacing.sm) {
                DetailPill(title: "Modules", value: "\(course.modules.count)", icon: "rectangle.3.group.bubble.left.fill")
                DetailPill(title: "Video lessons", value: "\(videoCount)", icon: "play.rectangle.fill")
                DetailPill(title: "Quizzes", value: "\(quizCount)", icon: "checkmark.square.fill")
                DetailPill(title: "Assignments", value: "\(assignmentCount)", icon: "doc.text.fill")
            }

            if !outcomes.isEmpty {
                Text("Learning outcomes")
                    .font(.subheadline.weight(.semibold))
                ForEach(Array(outcomes.enumerated()), id: \.offset) { _, outcome in
                    Text("• \(outcome)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("Implementation mirrors leading online learning platforms: structured modules, guided video flow, graded quizzes, assignment checkpoints, and progress tracking through API + middleware state hydration.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let report = course.courseReport {
                NavigationLink {
                    CourseReportView(courseTitle: course.title, report: report)
                } label: {
                    Label("Open course report", systemImage: "doc.text.magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .wcsInsetPanel()
    }

    @ViewBuilder
    private func enrollmentBlock(_ course: Course) -> some View {
        if course.isEnrolled {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("You’re enrolled")
                        .font(.headline.weight(.semibold))
                    Text("Lessons and assessments below are tracked to your profile.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(DesignTokens.Spacing.lg)
            .wcsElevatedSurface()
        } else {
            Button {
                Task { await viewModel.enroll() }
            } label: {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "person.badge.plus")
                        Text(enrollButtonTitle(for: course))
                            .font(.headline.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.sm)
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignTokens.brandAccent)
            .controlSize(.large)
        }
    }

    @ViewBuilder
    private func progressBlock(_ course: Course) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Overall progress")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(CourseHydration.progressFraction(for: course), format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(DesignTokens.brand)
            }
            ProgressView(value: CourseHydration.progressFraction(for: course))
                .tint(DesignTokens.brandAccent)
        }
        .padding(DesignTokens.Spacing.lg)
        .wcsElevatedSurface()
    }

    @ViewBuilder
    private func openScholarshipBlock(_ course: Course) -> some View {
        if !viewModel.crossrefScholarship.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text("Open scholarship (Crossref)")
                    .font(.headline.weight(.semibold))
                Text("DOI-linked research context for \(course.title). No API key required.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(viewModel.crossrefScholarship) { work in
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(work.title)
                            .font(.subheadline.weight(.semibold))
                        if let doi = work.doi {
                            Text(doi)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        if let url = work.resourceURL {
                            Link("Open landing page", destination: url)
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .padding(.vertical, DesignTokens.Spacing.xs)
                }
            }
            .wcsInsetPanel()
        }
    }

    @ViewBuilder
    private func phaseFourCompanionVideoBlock(_ course: Course) -> some View {
        if course.isEnrolled, !viewModel.companionVideoResults.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text("Build-up · Phase 4 — companion video from syllabus")
                    .font(.headline.weight(.semibold))
                Text(
                    "Each enrolled video lesson maps to a live YouTube search from your module titles and lesson names. "
                        + "Configure `YOUTUBE_DATA_API_KEY` (scheme or Info.plist via build setting). Open any video lesson to switch between the course feed and a selectable YouTube backup clip."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                ForEach(viewModel.companionVideoResults) { bundle in
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text(bundle.scriptLine.lessonTitle)
                            .font(.subheadline.weight(.semibold))
                        Text(bundle.scriptLine.moduleTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(bundle.scriptLine.youTubeSearchQuery)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(3)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DesignTokens.Spacing.sm) {
                                ForEach(bundle.snippets) { snippet in
                                    VStack(alignment: .leading, spacing: 6) {
                                        YouTubeEmbedWebView(videoID: snippet.videoID)
                                            .frame(width: 260, height: 146)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        Text(snippet.title)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                            .frame(width: 260, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, DesignTokens.Spacing.xs)
                }
            }
            .wcsInsetPanel()
        } else if course.isEnrolled, YouTubeSearchAPIClient.resolveAPIKey() == nil {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Optional companion YouTube embeds")
                    .font(.headline.weight(.semibold))
                Text("`YOUTUBE_DATA_API_KEY` (environment or `WCSYouTubeDataAPIKey` in Info.plist) is only needed for Phase 4 companion embeds. Core lecture playback uses the lesson `videoURL` and works without this key.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .wcsInsetPanel()
        }
    }

    @ViewBuilder
    private func lessonDestination(course: Course, module: Module, lesson: Lesson) -> some View {
        switch lesson.type {
        case .video:
            let backupSnippets = viewModel.companionSnippets(forLessonId: lesson.id)
            let primaryURL = lesson.videoURL.flatMap { URL(string: $0) }
            if backupSnippets.isEmpty {
                if let url = primaryURL {
                    VideoPlayerView(
                        url: url,
                        courseId: course.id,
                        moduleId: module.id,
                        lessonId: lesson.id,
                        title: lesson.title,
                        captionTracks: lesson.captionTracks,
                        serverResumePositionSeconds: lesson.serverResumePositionSeconds
                    )
                } else {
                    ContentUnavailableView(
                        "Missing video",
                        systemImage: "video.slash",
                        description: Text("This lesson has no playable URL yet. When enrolled with YouTube search configured, backup clips from your module can appear here.")
                    )
                }
            } else {
                LessonVideoWithYouTubeBackupView(
                    courseId: course.id,
                    moduleId: module.id,
                    lesson: lesson,
                    primaryVideoURL: primaryURL,
                    youtubeBackupSnippets: backupSnippets
                )
            }
        case .reading:
            ScrollView {
                ReadingLessonView(markdown: lesson.reading?.markdown ?? "_No reading content._")
                    .padding(DesignTokens.Spacing.lg)
            }
            .wcsGroupedScreen()
            .navigationTitle(lesson.title)
        case .quiz:
            if let quiz = lesson.quiz {
                QuizStartView(quiz: quiz, courseId: course.id, moduleId: module.id, lessonId: lesson.id)
            } else {
                ContentUnavailableView("Quiz unavailable", systemImage: "questionmark.square.dashed", description: Text("No quiz attached to this lesson."))
            }
        case .assignment:
            if let assignment = lesson.assignment {
                AssignmentLessonView(
                    assignment: assignment,
                    courseId: course.id,
                    moduleId: module.id,
                    lessonId: lesson.id
                )
            } else {
                ContentUnavailableView("Assignment unavailable", systemImage: "doc.text", description: Text("No assignment attached to this lesson."))
            }
        }
    }

    private func enrollButtonTitle(for course: Course) -> String {
        if let price = course.price {
            let money = price.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
            return "Enroll · \(money)"
        }
        return "Enroll for free"
    }

    private func extractOutcomes(from description: String) -> [String] {
        guard let range = description.range(of: "Learning outcomes:") else { return [] }
        let outcomesPart = String(description[range.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return outcomesPart
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private struct CourseReportView: View {
    let courseTitle: String
    let report: CourseReportSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                Text(courseTitle)
                    .font(.title3.weight(.bold))

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Design goals")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(report.designGoals)
                        .font(.body)
                }
                .wcsInsetPanel()

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Module overview")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(report.moduleOverview)
                        .font(.body)
                    Text("Cohort recommendation: \(report.cohortRecommendation)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .wcsInsetPanel()

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Learning outcomes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(Array(report.learningOutcomes.enumerated()), id: \.offset) { _, outcome in
                        Text("• \(outcome)")
                            .font(.subheadline)
                    }
                }
                .wcsInsetPanel()

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Course report findings")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(report.findings) { finding in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(finding.title)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("Conf. \(finding.confidence * 100, specifier: "%.0f%%")")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            Text(finding.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .wcsInsetPanel()
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .wcsGroupedScreen()
        .navigationTitle("Course Report")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DetailPill: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Label(title, systemImage: icon)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                .strokeBorder(DesignTokens.subtleBorder, lineWidth: 1)
        }
    }
}

private struct ReadingLessonView: View {
    let markdown: String

    var body: some View {
        Group {
            if let attributed = try? AttributedString(markdown: markdown) {
                Text(attributed)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(markdown)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.body)
    }
}

private struct AssignmentLessonView: View {
    let assignment: Assignment
    let courseId: UUID
    let moduleId: UUID
    let lessonId: UUID
    private let learningRepository: LearningRepository
    @State private var draft: String = ""
    @State private var isSubmitting = false
    @State private var localSubmission: Submission?
    @State private var errorText: String?

    init(
        assignment: Assignment,
        courseId: UUID,
        moduleId: UUID,
        lessonId: UUID,
        learningRepository: LearningRepository = WCSAppContainer.shared.learning
    ) {
        self.assignment = assignment
        self.courseId = courseId
        self.moduleId = moduleId
        self.lessonId = lessonId
        self.learningRepository = learningRepository
    }

    private var effectiveSubmission: Submission? {
        localSubmission ?? assignment.submission
    }

    var body: some View {
        Form {
            Section {
                Text(assignment.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            if let due = assignment.dueDate {
                Section("Due date") {
                    Text(due.formatted(date: .complete, time: .omitted))
                }
            }

            if let submission = effectiveSubmission {
                Section("Submission") {
                    if let content = submission.content, !content.isEmpty {
                        Text(content)
                    }
                    Text("Submitted \(submission.submittedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let fb = submission.feedback {
                        Text(fb)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Section("Your response") {
                    TextEditor(text: $draft)
                        .frame(minHeight: 168)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(AppEnvironment.simulatorStabilityMode ? .never : .sentences)
                        .simulatorStableTextSelection()
                        .scrollContentBackground(.hidden)
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Label("Submit assignment", systemImage: "paperplane.fill")
                        }
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
            }

            if let errorText {
                Section {
                    Text(errorText)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(assignment.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let s = assignment.submission, let c = s.content {
                draft = c
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        errorText = nil
        defer { isSubmitting = false }
        do {
            let submission = try await learningRepository.submitAssignment(
                assignmentId: assignment.id,
                content: draft,
                attachments: [],
                courseId: courseId,
                moduleId: moduleId,
                lessonId: lessonId
            )
            localSubmission = submission
        } catch let e as WCSAPIError {
            errorText = e.localizedDescription
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        CourseDetailView(courseId: MockCourseCatalog.courses[0].id)
    }
}
