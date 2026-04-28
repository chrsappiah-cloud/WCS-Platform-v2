//
//  VideoPlayerView.swift
//  WCS-Platform
//

import AVKit
import SwiftUI

struct VideoPlayerView: View {
    @StateObject private var viewModel: VideoPlayerViewModel
    let title: String
    @State private var liveEvents: [String] = []

    init(
        url: URL,
        courseId: UUID,
        moduleId: UUID,
        lessonId: UUID,
        title: String,
        captionTracks: [LessonCaptionTrack] = [],
        serverResumePositionSeconds: Double? = nil
    ) {
        self.title = title
        _viewModel = StateObject(
            wrappedValue: VideoPlayerViewModel(
                url: url,
                courseId: courseId,
                moduleId: moduleId,
                lessonId: lessonId,
                captionTracks: captionTracks,
                serverResumePositionSeconds: serverResumePositionSeconds
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                ZStack(alignment: .bottom) {
                    Group {
                        if viewModel.usesEmbeddedWebPlayer, let videoID = viewModel.embeddedYouTubeID {
                            YouTubeEmbedWebView(videoID: videoID)
                        } else {
                            VideoPlayer(player: viewModel.player)
                        }
                    }
                    if let caption = viewModel.sidecarCaptionText, !caption.isEmpty {
                        Text(caption)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DesignTokens.Spacing.md)
                            .padding(.vertical, DesignTokens.Spacing.sm)
                            .frame(maxWidth: .infinity)
                            .background(Color.black.opacity(0.62))
                            .accessibilityIdentifier("lessonVideoSidecarCaptionOverlay")
                    }
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                        .strokeBorder(DesignTokens.subtleBorder, lineWidth: 1)
                }
                .overlay(alignment: .topTrailing) {
                    if viewModel.usesEmbeddedWebPlayer || viewModel.isPlaying || viewModel.isBuffering {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(viewModel.isBuffering ? Color.orange : Color.red)
                                .frame(width: 8, height: 8)
                            Text(viewModel.isBuffering ? "LIVE · BUFFERING" : "LIVE")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.75), in: Capsule())
                        .padding(10)
                    }
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    if LessonVideoPlaybackPolicy.isHLSStreamURL(viewModel.sourceURL) {
                        Text("Adaptive streaming (HLS)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityIdentifier("lessonVideoHLSBadge")
                    }

                    HStack(spacing: DesignTokens.Spacing.md) {
                        if !viewModel.usesEmbeddedWebPlayer {
                            Button {
                                viewModel.togglePlayPause()
                            } label: {
                                Label(
                                    viewModel.isPlaying ? "Pause" : "Play",
                                    systemImage: viewModel.isPlaying ? "pause.fill" : "play.fill"
                                )
                                    .labelStyle(.iconOnly)
                                    .font(.title2)
                                    .frame(width: 52, height: 52)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(DesignTokens.brand)
                            .accessibilityIdentifier("lessonVideoPlayPause")
                        }

                        Spacer(minLength: 0)

                        Button {
                            Task { await viewModel.markLessonComplete() }
                        } label: {
                            Label("Mark complete", systemImage: "checkmark.circle.fill")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DesignTokens.brandAccent)
                    }

                    if !viewModel.usesEmbeddedWebPlayer {
                        HStack(spacing: DesignTokens.Spacing.md) {
                            Button {
                                viewModel.skip(by: -10)
                            } label: {
                                Image(systemName: "gobackward.10")
                                    .font(.title3.weight(.semibold))
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Skip back 10 seconds")

                            Button {
                                viewModel.skip(by: 10)
                            } label: {
                                Image(systemName: "goforward.10")
                                    .font(.title3.weight(.semibold))
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Skip forward 10 seconds")

                            Menu {
                                ForEach(LessonVideoPlaybackPolicy.udemyStylePlaybackRates, id: \.self) { rate in
                                    Button {
                                        viewModel.setPlaybackRate(rate)
                                    } label: {
                                        HStack {
                                            Text("\(Self.playbackSpeedMenuLabel(rate))×")
                                            if abs(viewModel.playbackRate - rate) < 0.0001 {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Label(
                                    "Speed \(Self.playbackSpeedMenuLabel(viewModel.playbackRate))×",
                                    systemImage: "gauge.with.dots.needle.67percent"
                                )
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, DesignTokens.Spacing.sm)
                                .padding(.vertical, DesignTokens.Spacing.xs)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("lessonVideoSpeedMenu")

                            Spacer(minLength: 0)
                        }
                    }

                    if !viewModel.usesEmbeddedWebPlayer {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            if !viewModel.captionTracks.isEmpty {
                                Menu {
                                    Button("Off") { viewModel.selectSidecarCaptionIndex(0) }
                                    ForEach(Array(viewModel.captionTracks.enumerated()), id: \.offset) { offset, track in
                                        Button(track.label) {
                                            viewModel.selectSidecarCaptionIndex(offset + 1)
                                        }
                                    }
                                } label: {
                                    Label("Captions", systemImage: "captions.bubble")
                                        .font(.caption.weight(.semibold))
                                }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("lessonVideoSidecarCaptionMenu")
                            }

                            if !viewModel.manifestCaptionMenuLabels.isEmpty {
                                Menu {
                                    Button("Automatic") { viewModel.selectManifestCaptionMenuIndex(0) }
                                    ForEach(Array(viewModel.manifestCaptionMenuLabels.enumerated()), id: \.offset) { offset, label in
                                        Button(label) {
                                            viewModel.selectManifestCaptionMenuIndex(offset + 1)
                                        }
                                    }
                                } label: {
                                    Label("Stream captions", systemImage: "text.bubble")
                                        .font(.caption.weight(.semibold))
                                }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("lessonVideoManifestCaptionMenu")
                            }

                            if LessonVideoPlaybackPolicy.isHLSStreamURL(viewModel.sourceURL) {
                                Menu {
                                    ForEach(HLSQualityPreset.allCases) { preset in
                                        Button {
                                            viewModel.setQualityPreset(preset)
                                        } label: {
                                            HStack {
                                                Text(preset.menuLabel)
                                                if viewModel.qualityPreset == preset {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    Label("Quality", systemImage: "film")
                                        .font(.caption.weight(.semibold))
                                }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("lessonVideoQualityMenu")
                            }

                            Spacer(minLength: 0)
                        }
                    }

                    if !viewModel.usesEmbeddedWebPlayer, viewModel.totalSeconds > 0 {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Slider(
                                value: Binding(
                                    get: { viewModel.progressSeconds / max(viewModel.totalSeconds, 0.0001) },
                                    set: { viewModel.seek(toFraction: $0) }
                                )
                            )
                            .tint(DesignTokens.brandAccent)
                            Text(timelineText)
                                .font(.caption.monospacedDigit().weight(.medium))
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("videoTimelineLabel")
                        }
                    }

                    if viewModel.usesEmbeddedWebPlayer {
                        Text("Playing live module support video from YouTube.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let error = viewModel.lastError {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Live monitoring analytics")
                            .font(.caption.weight(.semibold))
                        if liveEvents.isEmpty {
                            Text("No live playback events yet.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(liveEvents.enumerated()), id: \.offset) { _, item in
                                Text(item)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                .padding(DesignTokens.Spacing.md)
                .wcsElevatedSurface()
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .wcsGroupedScreen()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .onAppear {
            refreshLiveEvents()
        }
        .onReceive(NotificationCenter.default.publisher(for: .wcsTelemetryDidUpdate)) { _ in
            refreshLiveEvents()
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }

    private var timelineText: String {
        let cur = Int(viewModel.progressSeconds.rounded(.down))
        let tot = Int(viewModel.totalSeconds.rounded(.down))
        return "\(format(cur)) / \(format(tot))"
    }

    private func format(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private static func playbackSpeedMenuLabel(_ rate: Float) -> String {
        switch rate {
        case 0.75: return "0.75"
        case 1.0: return "1"
        case 1.25: return "1.25"
        case 1.5: return "1.5"
        case 2.0: return "2"
        default:
            return String(format: "%g", rate)
        }
    }

    private func refreshLiveEvents() {
        liveEvents = Telemetry.recentEvents(prefix: "lesson.video.playback", limit: 8)
    }
}

#Preview {
    NavigationStack {
        VideoPlayerView(
            url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!,
            courseId: UUID(),
            moduleId: UUID(),
            lessonId: UUID(),
            title: "Preview (HLS)",
            captionTracks: [
                LessonCaptionTrack(
                    language: "en",
                    label: "English (demo)",
                    webvttURL: "embedded:wcs-investor-en"
                ),
            ],
            serverResumePositionSeconds: nil
        )
    }
}
