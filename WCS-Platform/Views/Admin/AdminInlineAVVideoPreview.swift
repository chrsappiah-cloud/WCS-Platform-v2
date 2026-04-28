//
//  AdminInlineAVVideoPreview.swift
//  WCS-Platform
//
//  Compact AVKit preview for admin “generated assets” (HTTPS MP4 / HLS / signed URLs).
//

import AVKit
import SwiftUI

struct AdminInlineAVVideoPreview: View {
    @StateObject private var viewModel: VideoPlayerViewModel

    init(url: URL, courseId: UUID, moduleId: UUID, lessonId: UUID) {
        _viewModel = StateObject(
            wrappedValue: VideoPlayerViewModel(
                url: url,
                courseId: courseId,
                moduleId: moduleId,
                lessonId: lessonId,
                captionTracks: [],
                serverResumePositionSeconds: nil
            )
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if viewModel.usesEmbeddedWebPlayer, let videoID = viewModel.embeddedYouTubeID {
                YouTubeEmbedWebView(videoID: videoID)
            } else {
                VideoPlayer(player: viewModel.player)
            }
            if let error = viewModel.lastError {
                Text(error.localizedDescription)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(6)
                    .frame(maxWidth: .infinity)
                    .background(.black.opacity(0.55))
            }
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
}
