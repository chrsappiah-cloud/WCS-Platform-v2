//
//  LessonVideoFeaturesPreviews.swift
//  WCS-Platform
//
//  SwiftUI previews for lesson-video admin features (Xcode canvas; no Info.plist / Edge required).
//

import SwiftUI

private struct LessonVideoJobAuditSampleList: View {
    let jobs: [LessonVideoRenderJobRow]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Lesson video render audit (Supabase)")
                .font(.headline.weight(.semibold))

            Text("Preview sample data — configure plist + Edge for live job list.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            ForEach(jobs) { job in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(job.status) · \(job.provider) · lesson \(job.lessonId.prefix(8))…")
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
        .wcsInsetPanel()
        .padding()
    }
}

#Preview("Lesson video — job audit (sample rows)") {
    ScrollView {
        LessonVideoJobAuditSampleList(jobs: LessonVideoRenderJobRow.previewSamples)
    }
}

#Preview("Lesson video — inline AV (Apple sample HLS)") {
    let course = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let module = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let lesson = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
    let url = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!

    AdminInlineAVVideoPreview(url: url, courseId: course, moduleId: module, lessonId: lesson)
        .frame(width: 320, height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding()
}
