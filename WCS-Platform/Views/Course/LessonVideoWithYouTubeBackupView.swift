//
//  LessonVideoWithYouTubeBackupView.swift
//  WCS-Platform
//
//  Primary lesson stream (catalog `videoURL`) plus module-aligned YouTube Data API results as a
//  selectable streaming backup when enrolled and `YOUTUBE_DATA_API_KEY` is configured.
//

import AVKit
import SwiftUI

/// Segmented playback: native/HLS course feed vs. YouTube embed chosen from `ModuleVideoDiscoveryPipeline` snippets for this lesson.
struct LessonVideoWithYouTubeBackupView: View {
    let courseId: UUID
    let moduleId: UUID
    let lesson: Lesson
    let primaryVideoURL: URL?
    let youtubeBackupSnippets: [YouTubeVideoSnippet]

    private enum PlaybackTab: String, CaseIterable {
        case primary = "Course video"
        case youtube = "YouTube backup"
    }

    @State private var tab: PlaybackTab = .primary
    @State private var selectedYouTubeVideoID: String = ""

    private var storageKey: String {
        "wcs.lessonYouTubeModuleBackup.\(courseId.uuidString).\(lesson.id.uuidString).videoId"
    }

    private var primaryHostsYouTube: Bool {
        primaryVideoURL.flatMap { LessonVideoPlaybackPolicy.youTubeVideoID(from: $0) } != nil
    }

    private var hasPrimaryStream: Bool {
        guard let url = primaryVideoURL else { return false }
        return LessonVideoPlaybackPolicy.youTubeVideoID(from: url) != nil
            || LessonVideoPlaybackPolicy.isNativeAVPlayerHTTPSURL(url)
    }

    private var showSegmentedTabs: Bool {
        hasPrimaryStream && !youtubeBackupSnippets.isEmpty && !primaryHostsYouTube
    }

    var body: some View {
        Group {
            if primaryHostsYouTube, let url = primaryVideoURL {
                VideoPlayerView(
                    url: url,
                    courseId: courseId,
                    moduleId: moduleId,
                    lessonId: lesson.id,
                    title: lesson.title,
                    captionTracks: lesson.captionTracks,
                    serverResumePositionSeconds: lesson.serverResumePositionSeconds
                )
            } else if youtubeBackupSnippets.isEmpty, let url = primaryVideoURL {
                VideoPlayerView(
                    url: url,
                    courseId: courseId,
                    moduleId: moduleId,
                    lessonId: lesson.id,
                    title: lesson.title,
                    captionTracks: lesson.captionTracks,
                    serverResumePositionSeconds: lesson.serverResumePositionSeconds
                )
            } else if !youtubeBackupSnippets.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    if showSegmentedTabs {
                        Picker("Playback source", selection: $tab) {
                            Text(PlaybackTab.primary.rawValue).tag(PlaybackTab.primary)
                            Text(PlaybackTab.youtube.rawValue).tag(PlaybackTab.youtube)
                        }
                        .pickerStyle(.segmented)
                    }

                    if tab == .primary, let url = primaryVideoURL {
                        VideoPlayerView(
                            url: url,
                            courseId: courseId,
                            moduleId: moduleId,
                            lessonId: lesson.id,
                            title: lesson.title,
                            captionTracks: lesson.captionTracks,
                            serverResumePositionSeconds: lesson.serverResumePositionSeconds
                        )
                    } else {
                        youtubeBackupPanel
                    }
                }
                .navigationTitle(lesson.title)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView(
                    "No playback yet",
                    systemImage: "video.slash",
                    description: Text("This lesson has no course video URL and no YouTube backup clips were found. Enroll and configure YouTube search, or ask your instructor to publish a video link.")
                )
                .navigationTitle(lesson.title)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task(id: lesson.id.uuidString) {
            restoreSelection()
            if !hasPrimaryStream, !youtubeBackupSnippets.isEmpty {
                tab = .youtube
            }
        }
        .onChange(of: selectedYouTubeVideoID) { _, newValue in
            guard !newValue.isEmpty else { return }
            UserDefaults.standard.set(newValue, forKey: storageKey)
        }
    }

    @ViewBuilder
    private var youtubeBackupPanel: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("YouTube module backup")
                .font(.subheadline.weight(.semibold))
            Text("Clips are matched to this lesson from your module title and lesson name. Pick one to stream here if the course feed buffers or is unavailable.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if youtubeBackupSnippets.count > 1 {
                Picker("Clip", selection: $selectedYouTubeVideoID) {
                    ForEach(youtubeBackupSnippets) { snippet in
                        Text(snippet.title)
                            .lineLimit(1)
                            .tag(snippet.videoID)
                    }
                }
                .pickerStyle(.menu)
            }

            if let id = sanitizedYouTubeID(selectedYouTubeVideoID) {
                YouTubeEmbedWebView(videoID: id)
                    .frame(minHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                            .strokeBorder(DesignTokens.subtleBorder, lineWidth: 1)
                    }
            }
        }
    }

    private func restoreSelection() {
        if let stored = UserDefaults.standard.string(forKey: storageKey),
           youtubeBackupSnippets.contains(where: { $0.videoID == stored }) {
            selectedYouTubeVideoID = stored
        } else if let first = youtubeBackupSnippets.first?.videoID {
            selectedYouTubeVideoID = first
        } else {
            selectedYouTubeVideoID = ""
        }
    }

    private func sanitizedYouTubeID(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        return trimmed.unicodeScalars.allSatisfy { allowed.contains($0) } ? trimmed : nil
    }
}

// MARK: - SwiftUI previews (Xcode canvas)

private enum LessonVideoWithYouTubeBackupPreviewData {
    static let courseId = UUID(uuidString: "10000000-0000-0000-0000-000000000099")!
    static let moduleId = UUID(uuidString: "20000000-0000-0000-0000-000000000099")!
    static let lessonId = UUID(uuidString: "30000000-0000-0000-0000-000000000099")!

    static var lesson: Lesson {
        Lesson(
            id: lessonId,
            title: "Foundations · preview",
            subtitle: "Open the YouTube backup tab or clip menu.",
            type: .video,
            videoURL: "https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            durationSeconds: 600,
            isCompleted: false,
            isAvailable: true,
            isUnlocked: true,
            reading: nil,
            quiz: nil,
            assignment: nil
        )
    }

    static var lessonNoPrimary: Lesson {
        Lesson(
            id: lessonId,
            title: "Backup-only lesson · preview",
            subtitle: nil,
            type: .video,
            videoURL: nil,
            durationSeconds: 600,
            isCompleted: false,
            isAvailable: true,
            isUnlocked: true,
            reading: nil,
            quiz: nil,
            assignment: nil
        )
    }

    /// Public-domain style IDs suitable for embed smoke tests in the canvas.
    static var snippets: [YouTubeVideoSnippet] {
        [
            YouTubeVideoSnippet(videoID: "aqz-KE-bpKQ", title: "Sample A · Big Buck Bunny (YouTube)", thumbnailURL: nil),
            YouTubeVideoSnippet(videoID: "eOrNdBpGMv8", title: "Sample B · Elephants Dream trailer", thumbnailURL: nil),
        ]
    }
}

#Preview("Lesson · course video + YouTube backup (segmented)") {
    NavigationStack {
        LessonVideoWithYouTubeBackupView(
            courseId: LessonVideoWithYouTubeBackupPreviewData.courseId,
            moduleId: LessonVideoWithYouTubeBackupPreviewData.moduleId,
            lesson: LessonVideoWithYouTubeBackupPreviewData.lesson,
            primaryVideoURL: URL(string: LessonVideoWithYouTubeBackupPreviewData.lesson.videoURL ?? ""),
            youtubeBackupSnippets: LessonVideoWithYouTubeBackupPreviewData.snippets
        )
    }
}

#Preview("Lesson · YouTube backup only (no primary URL)") {
    NavigationStack {
        LessonVideoWithYouTubeBackupView(
            courseId: LessonVideoWithYouTubeBackupPreviewData.courseId,
            moduleId: LessonVideoWithYouTubeBackupPreviewData.moduleId,
            lesson: LessonVideoWithYouTubeBackupPreviewData.lessonNoPrimary,
            primaryVideoURL: nil,
            youtubeBackupSnippets: LessonVideoWithYouTubeBackupPreviewData.snippets
        )
    }
}
