//
//  VideoPlayerViewModel.swift
//  WCS-Platform
//

import AVFoundation
import Combine
import Foundation
import OSLog

final class VideoPlayerViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var isBuffering = false
    @Published var progressSeconds: Double = 0
    @Published var totalSeconds: Double = 0
    @Published var lastError: WCSAPIError?
    @Published var usesEmbeddedWebPlayer = false

    let player: AVPlayer
    let embeddedYouTubeID: String?

    private var timeObserverToken: Any?
    private var statusCancellable: AnyCancellable?
    private var timeControlCancellable: AnyCancellable?
    private var hasAttemptedHostRecovery = false

    private let courseId: UUID
    private let moduleId: UUID
    private let lessonId: UUID
    private let originalURL: URL
    private let learningRepository: LearningRepository
    private static let logger = Logger(subsystem: "wcs.platform.ios", category: "lesson-video")
    private var didLogPlaybackStart = false
    private var lastHeartbeatSecond: Int = -1
    private var lastBufferingState: Bool?

    init(
        url: URL,
        courseId: UUID,
        moduleId: UUID,
        lessonId: UUID,
        learningRepository: LearningRepository = WCSAppContainer.shared.learning
    ) {
        self.courseId = courseId
        self.moduleId = moduleId
        self.lessonId = lessonId
        self.originalURL = url
        self.learningRepository = learningRepository
        let youtubeID = Self.extractYouTubeVideoID(from: url)
        self.embeddedYouTubeID = youtubeID
        self.usesEmbeddedWebPlayer = youtubeID != nil

        // Physical devices route lesson playback through the shared audio session; activate playback category.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [.defaultToSpeaker])
            try session.setActive(true, options: [])
        } catch {
            Self.logger.error("AVAudioSession activation failed: \(String(describing: error), privacy: .public)")
        }

        if youtubeID != nil {
            self.player = AVPlayer()
            return
        }

        self.player = AVPlayer(url: url)

        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.tick(time: time)
        }

        statusCancellable = player.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatus()
            }

        timeControlCancellable = player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncPlaybackState()
            }

        // Start playback immediately for lesson videos so learners/admins see motion without extra taps.
        player.play()
        syncPlaybackState()
    }

    deinit {
        cleanup()
    }

    func cleanup() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        statusCancellable?.cancel()
        statusCancellable = nil
        timeControlCancellable?.cancel()
        timeControlCancellable = nil
        player.pause()
    }

    private func tick(time: CMTime) {
        let current = CMTimeGetSeconds(time)
        progressSeconds = current.isFinite ? current : 0

        if let duration = player.currentItem?.duration, duration.isValid, !duration.isIndefinite {
            let total = CMTimeGetSeconds(duration)
            totalSeconds = total.isFinite && total > 0 ? total : 0
        }

        emitPlaybackHeartbeatIfNeeded()
    }

    private func updateStatus() {
        switch player.status {
        case .readyToPlay:
            if player.timeControlStatus != .playing {
                player.play()
            }
            syncPlaybackState()
        case .failed:
            isPlaying = false
            isBuffering = false
            Telemetry.event(
                "lesson.video.playback.failed",
                attributes: [
                    "courseId": courseId.uuidString,
                    "moduleId": moduleId.uuidString,
                    "lessonId": lessonId.uuidString,
                ]
            )
            if attemptHostRecoveryIfNeeded() {
                return
            }
            lastError = WCSAPIError(
                underlying: player.error ?? URLError(.unknown),
                statusCode: nil,
                body: nil
            )
        default:
            isPlaying = false
            isBuffering = true
        }
    }

    func togglePlayPause() {
        guard !usesEmbeddedWebPlayer else { return }
        if player.rate > 0 {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            syncPlaybackState()
        }
    }

    func seek(toFraction fraction: Double) {
        guard !usesEmbeddedWebPlayer else { return }
        let clamped = min(1, max(0, fraction))
        let seconds = clamped * totalSeconds
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time)
    }

    func markLessonComplete() async {
        do {
            _ = try await learningRepository.markProgress(
                programId: courseId,
                moduleId: moduleId,
                lessonId: lessonId,
                complete: true
            )
        } catch let api as WCSAPIError {
            lastError = api
        } catch {
            lastError = WCSAPIError(underlying: error, statusCode: nil, body: nil)
        }
    }

    @discardableResult
    private func attemptHostRecoveryIfNeeded() -> Bool {
        guard !hasAttemptedHostRecovery else { return false }
        guard originalURL.host?.lowercased() == "commondatastorage.googleapis.com" else { return false }
        guard var components = URLComponents(url: originalURL, resolvingAgainstBaseURL: false) else { return false }

        hasAttemptedHostRecovery = true
        components.host = "storage.googleapis.com"
        guard let rewritten = components.url else { return false }

        player.replaceCurrentItem(with: AVPlayerItem(url: rewritten))
        player.play()
        syncPlaybackState()
        return true
    }

    private func syncPlaybackState() {
        let isActuallyPlaying = player.timeControlStatus == .playing && player.rate > 0
        isPlaying = isActuallyPlaying
        isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
        if lastBufferingState != isBuffering {
            lastBufferingState = isBuffering
            Telemetry.event(
                isBuffering ? "lesson.video.playback.buffering.started" : "lesson.video.playback.buffering.ended",
                attributes: [
                    "courseId": courseId.uuidString,
                    "moduleId": moduleId.uuidString,
                    "lessonId": lessonId.uuidString,
                    "positionSec": "\(Int(progressSeconds.rounded(.down)))",
                ]
            )
        }
        if isActuallyPlaying, !didLogPlaybackStart {
            didLogPlaybackStart = true
            Self.logger.info("Lesson video playback started (timeControlStatus=playing).")
            Telemetry.event(
                "lesson.video.playback.started",
                attributes: [
                    "courseId": courseId.uuidString,
                    "moduleId": moduleId.uuidString,
                    "lessonId": lessonId.uuidString,
                ]
            )
        }
    }

    private func emitPlaybackHeartbeatIfNeeded() {
        guard isPlaying else { return }
        let second = Int(progressSeconds.rounded(.down))
        guard second >= 0 else { return }
        guard lastHeartbeatSecond < 0 || second - lastHeartbeatSecond >= 10 else { return }
        lastHeartbeatSecond = second
        Telemetry.event(
            "lesson.video.playback.heartbeat",
            attributes: [
                "courseId": courseId.uuidString,
                "moduleId": moduleId.uuidString,
                "lessonId": lessonId.uuidString,
                "positionSec": "\(second)",
                "durationSec": "\(Int(totalSeconds.rounded(.down)))",
            ]
        )
    }

    private static func extractYouTubeVideoID(from url: URL) -> String? {
        let host = (url.host ?? "").lowercased()
        if host.contains("youtu.be") {
            let id = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return id.count == 11 ? id : nil
        }
        guard host.contains("youtube.com") else { return nil }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        if let id = components.queryItems?.first(where: { $0.name == "v" })?.value, id.count == 11 {
            return id
        }
        let path = components.path.lowercased()
        if path.contains("/embed/"), let last = components.path.split(separator: "/").last {
            let id = String(last)
            return id.count == 11 ? id : nil
        }
        return nil
    }
}
