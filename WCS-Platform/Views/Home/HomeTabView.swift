//
//  HomeTabView.swift
//  WCS-Platform
//

import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    private let catalogRepository: CatalogRepository
    @State private var discoverPayload: DiscoverPayload?
    @State private var featuredCourses: [Course] = []

    init(catalogRepository: CatalogRepository = WCSAppContainer.shared.catalog) {
        self.catalogRepository = catalogRepository
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text("Discover")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.brandAccent)
                        .textCase(.uppercase)
                        .tracking(1.2)

                    Text("Open learning, WCS-owned")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignTokens.brand)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Programs, sequenced modules, graded assessments, and progress you can trust—presented with the clarity learners expect from a modern catalog.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !featuredCourses.isEmpty {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        Text("Featured programs")
                            .wcsSectionTitle()

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DesignTokens.Spacing.md) {
                                ForEach(featuredCourses.prefix(6)) { course in
                                    NavigationLink {
                                        CourseDetailView(courseId: course.id)
                                    } label: {
                                        CourseCardView(course: course)
                                            .frame(width: 320)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                HomeCourseDesignerContactCard()

                HomeLearnerTestimonialsSection()

                if let enrollments = appViewModel.user?.enrollments, !enrollments.isEmpty {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        Text("Resume learning")
                            .wcsSectionTitle()

                        Text("Pick up where you left off. Progress updates when you complete lessons or submit work.")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DesignTokens.Spacing.md) {
                                ForEach(enrollments) { enrollment in
                                    NavigationLink {
                                        CourseDetailView(courseId: enrollment.courseId)
                                    } label: {
                                        ResumeProgramCard(enrollment: enrollment)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                NavigationLink {
                    CourseListView()
                } label: {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(DesignTokens.brandAccentSubtle)
                                .frame(width: 52, height: 52)
                            Image(systemName: "rectangle.stack.fill.badge.person.crop")
                                .font(.title2.weight(.semibold))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(DesignTokens.brandAccent)
                        }

                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("Explore catalog")
                                .font(.headline.weight(.semibold))
                            Text("Search programs, compare effort and level, then enroll or audit.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(DesignTokens.Spacing.lg)
                    .wcsElevatedSurface()
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text("Quick access")
                        .wcsSectionTitle()
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Button {
                            appViewModel.openTab(.discussion)
                        } label: {
                            Label("Open Discussion", systemImage: "bubble.left.and.bubble.right.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DesignTokens.brandAccent)

                        Button {
                            appViewModel.openTab(.programs)
                        } label: {
                            Label("Browse Programs", systemImage: "square.grid.2x2.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text("Social media systems")
                        .wcsSectionTitle()
                    Text("Live channels are active for community updates, module highlights, and learner support.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            ForEach(BrandOutboundLinks.current.socialPairs, id: \.label) { item in
                                Link(destination: item.url) {
                                    Label(item.label, systemImage: socialIcon(for: item.label))
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(.tertiarySystemFill), in: Capsule())
                                }
                            }
                        }
                    }
                }
                .wcsInsetPanel()

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text("Platform capabilities")
                        .wcsSectionTitle()

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        CapabilityRow(icon: "play.rectangle.fill", title: "Structured programs", subtitle: "Modules, lessons, and pacing with completion state.")
                        CapabilityRow(icon: "chart.bar.doc.horizontal", title: "Assessments", subtitle: "Quizzes with scoring; assignments with submission and feedback.")
                        CapabilityRow(icon: "person.text.rectangle", title: "Identity-ready client", subtitle: "Bearer token from UserDefaults for live backends.")
                        CapabilityRow(icon: "creditcard.fill", title: "Commerce-ready models", subtitle: "Price, enrollment, and subscription fields match your domain.")
                    }
                    .wcsInsetPanel()
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.lg)
        }
        .wcsGroupedScreen()
        .navigationTitle("Discover")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .task {
            await appViewModel.bootstrapUser()
            await loadFeatured()
        }
        .onReceive(NotificationCenter.default.publisher(for: .wcsLearningStateDidChange)) { _ in
            guard !AppEnvironment.debugSafeMode else { return }
            Task { await loadFeatured() }
        }
    }

    private func loadFeatured() async {
        if let payload = try? await catalogRepository.fetchDiscoverPayload() {
            discoverPayload = payload
            featuredCourses = payload.featuredPrograms.map(\.course)
        } else {
            featuredCourses = (try? await catalogRepository.fetchAvailableCourses()) ?? []
        }
    }

    private func socialIcon(for label: String) -> String {
        switch label.lowercased() {
        case "youtube":
            return "play.rectangle.fill"
        case "instagram":
            return "camera.fill"
        case "facebook":
            return "person.2.circle.fill"
        case "linkedin":
            return "briefcase.fill"
        case "tiktok":
            return "music.note"
        case "x":
            return "bubble.left.and.bubble.right.fill"
        default:
            return "link"
        }
    }
}

private struct ResumeProgramCard: View {
    let enrollment: Enrollment

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            AsyncImage(url: MockCourseCatalog.thumbnailURL(for: enrollment.courseId)) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(DesignTokens.brandMuted)
                        .frame(height: 72)
                        .overlay { ProgressView() }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 72)
                        .clipped()
                case .failure:
                    Rectangle()
                        .fill(DesignTokens.brandMuted)
                        .frame(height: 72)
                        .overlay {
                            Image(systemName: "book.closed.fill")
                                .foregroundStyle(DesignTokens.brand)
                        }
                @unknown default:
                    EmptyView()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))

            Text(MockCourseCatalog.displayTitle(for: enrollment.courseId))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            ProgressView(value: enrollment.progressPercentage)
                .tint(DesignTokens.brandAccent)

            Text(enrollment.progressPercentage, format: .percent.precision(.fractionLength(0)))
                .font(.caption2.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(DesignTokens.Spacing.md)
        .frame(width: 216, alignment: .leading)
        .wcsElevatedSurface()
    }
}

private struct CapabilityRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(DesignTokens.brandAccent)
                .frame(width: 28, height: 28)
                .background(Circle().fill(DesignTokens.brandAccentSubtle))

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    NavigationStack {
        HomeTabView()
            .environmentObject(AppViewModel())
    }
}
