//
//  CourseCardView.swift
//  WCS-Platform
//

import SwiftUI

struct CourseCardView: View {
    let course: Course

    private var imageURL: URL? {
        let raw = course.coverURL ?? course.thumbnailURL
        return URL(string: raw)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [DesignTokens.brand, DesignTokens.brand.opacity(0.65)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay {
                                    ProgressView()
                                        .controlSize(.regular)
                                        .tint(.white.opacity(0.9))
                                }
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Rectangle()
                                .fill(DesignTokens.brand.opacity(0.55))
                                .overlay {
                                    Image(systemName: "photo")
                                        .font(.system(size: 28, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.85))
                                }
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(height: 152)
                    .clipped()

                    DesignTokens.heroGradient
                        .frame(height: 152)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        if let org = course.organizationName {
                            Text(org.uppercased())
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white.opacity(0.92))
                                .lineLimit(1)
                        }
                        Text(course.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                            .lineLimit(2)
                    }
                    .padding(DesignTokens.Spacing.md)
                }

                if course.isEnrolled {
                    Text("Enrolled")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(DesignTokens.Spacing.sm)
                }
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                if let subtitle = course.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                FlowMetaRow(course: course)

                if course.isEnrolled {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Your progress")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(CourseHydration.progressFraction(for: course), format: .percent.precision(.fractionLength(0)))
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(DesignTokens.brand)
                        }
                        ProgressView(value: CourseHydration.progressFraction(for: course))
                            .tint(DesignTokens.brandAccent)
                    }
                    .padding(.top, DesignTokens.Spacing.xs)
                } else {
                    Text("Free to audit")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.brand)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(DesignTokens.brandAccentSubtle, in: Capsule())
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .strokeBorder(DesignTokens.subtleBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 5)
        .accessibilityIdentifier("programCard-\(course.title)")
    }
}

private struct FlowMetaRow: View {
    let course: Course

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: DesignTokens.Spacing.sm)], alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            if let level = course.level {
                MetaChip(icon: "stairs", text: level)
            }
            if let effort = course.effortDescription {
                MetaChip(icon: "clock", text: effort)
            }
            MetaChip(icon: "globe", text: course.displayLanguages)
            if let rating = course.rating {
                MetaChip(icon: "star.fill", text: String(format: "%.1f", rating))
            }
        }
    }
}

private struct MetaChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(text)
        }
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(.tertiarySystemFill))
            )
            .overlay {
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
            }
    }
}

#Preview {
    CourseCardView(course: MockCourseCatalog.courses[0])
        .padding()
        .wcsGroupedScreen()
}
