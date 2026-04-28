//
//  HomeTrustClusterViews.swift
//  WCS-Platform
//
//  Course designer contact + learner testimonials (home trust cluster).
//

import SwiftUI

// MARK: - Course designer

struct HomeCourseDesignerContactCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(HomeTrustClusterContent.designerSectionEyebrow)
                .font(.caption.weight(.bold))
                .foregroundStyle(DesignTokens.brandAccent)
                .textCase(.uppercase)
                .tracking(1.0)

            Text(HomeTrustClusterContent.designerName)
                .font(.title3.weight(.bold))
                .foregroundStyle(DesignTokens.brand)
                .fixedSize(horizontal: false, vertical: true)

            Text(HomeTrustClusterContent.designerBlurb)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DesignTokens.Spacing.md) {
                if let mailURL = HomeTrustClusterContent.courseTeamMailURL {
                    Link(destination: mailURL) {
                        Label(HomeTrustClusterContent.emailCourseTeamLabel, systemImage: "envelope.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DesignTokens.brandAccent)
                }
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wcsElevatedSurface()
    }
}

// MARK: - Learner testimonials

struct HomeLearnerTestimonialsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(HomeTrustClusterContent.testimonialsSectionTitle)
                .wcsSectionTitle()

            Text(HomeTrustClusterContent.testimonialsPlaceholderDisclaimer)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            TabView {
                ForEach(HomeTrustClusterContent.learnerTestimonialPages) { item in
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("“\(item.quote)”")
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("— \(item.name)")
                            .font(.subheadline.weight(.semibold))
                        Text(item.role)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(DesignTokens.Spacing.lg)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .wcsElevatedSurface(cornerRadius: DesignTokens.Radius.md)
                }
            }
            .frame(height: 220)
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))

            if let storiesURL = BrandOutboundLinks.current.linkedInURL {
                Link(destination: storiesURL) {
                    Label(HomeTrustClusterContent.seeLearnerStoriesLabel, systemImage: "person.2.wave.2.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .strokeBorder(DesignTokens.subtleBorder, lineWidth: 1)
        }
    }
}

// MARK: - Previews

#Preview("Discover — trust cluster") {
    ScrollView {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            Text("Preview: Featured programs would appear above this block in HomeTabView.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HomeCourseDesignerContactCard()

            HomeLearnerTestimonialsSection()
        }
        .padding(DesignTokens.Spacing.lg)
    }
    .wcsGroupedScreen()
}
