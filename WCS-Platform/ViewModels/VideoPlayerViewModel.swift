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
    /// Udemy-style discrete rates (see `LessonVideoPlaybackPolicy`).
    @Published private(set) var playbackRate: Float = 1.0
    /// Sidecar WebVTT overlay (when a track is selected).
    @Published private(set) var sidecarCaptionText: String?
    /// 0 = off; 1…n maps to `captionTracks` order.
    @Published private(set) var selectedSidecarCaptionIndex: Int = 0
    /// HLS manifest legible options (when the asset exposes `.legible`).
    @Published private(set) var manifestCaptionMenuLabels: [String] = []
    /// 0 = automatic; 1… maps to `manifestLegibleOptions`.
    @Published private(set) var manifestCaptionMenuIndex: Int = 0
    /// Manual quality ceiling on top of ABR.
    @Published private(set) var qualityPreset: HLSQualityPreset = .auto

    let player: AVPlayer
    let embeddedYouTubeID: String?

    /// Lesson `videoURL` (HLS master, progressive MP4, or YouTube).
    private(set) var sourceURL: URL

    let captionTracks: [LessonCaptionTrack]

    private var timeObserverToken: Any?
    private var statusCancellable: AnyCancellable?
    private var timeControlCancellable: AnyCancellable?
    private var hasAttemptedHostRecovery = false
    private var didApplyResumeBookmark = false
    private let resumeBookmarkSeconds: Double?
    private var lastResumeWrite = Date.distantPast
    private var lastServerWatchFlush = Date.distantPast

    private var sidecarCues: [WebVTTCue] = []
    private var manifestLegibleGroup: AVMediaSelectionGroup?
    private var manifestLegibleOptions: [AVMediaSelectionOption] = []
    private var didAttemptManifestCaptionLoad = false

    private let courseId: UUID
    private let moduleId: UUID
    private let lessonId: UUID
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
        captionTracks: [LessonCaptionTrack] = [],
        serverResumePositionSeconds: Double? = nil,
        learningRepository: LearningRepository = WCSAppContainer.shared.learning
    ) {
        self.courseId = courseId
        self.moduleId = moduleId
        self.lessonId = lessonId
        self.sourceURL = url
        self.captionTracks = captionTracks
        self.learningRepository = learningRepository
        let youtubeID = LessonVideoPlaybackPolicy.youTubeVideoID(from: url)
        self.embeddedYouTubeID = youtubeID
        self.usesEmbeddedWebPlayer = youtubeID != nil
        let resumeKey = LessonVideoPlaybackPolicy.resumeStorageKey(courseId: courseId, lessonId: lessonId)
        let localRaw = UserDefaults.standard.double(forKey: resumeKey)
        let local = localRaw > 0.5 ? localRaw : nil
        let server = serverResumePositionSeconds.flatMap { $0 > 0.5 ? $0 : nil }
        let merged = [local, server].compactMap { $0 }
        self.resumeBookmarkSeconds = merged.max()

        // Physical devices route lesson playback through the shared audio session; activate playback category.
        // Note: `.defaultToSpeaker` is only valid with `.playAndRecord` (SessionCore logs a warning if combined with `.playback`).
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true, options: [])
        } catch {
            Self.logger.error("AVAudioSession activation failed: \(String(describing: error), privacy: .public)")
        }

        if youtubeID != nil {
            self.player = AVPlayer()
            return
        }

        self.player = AVPlayer(url: url)
        configureCurrentItemForUdemyStylePlayback()

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
        player.playImmediately(atRate: playbackRate)
        syncPlaybackState()

        Task { @MainActor in
            guard !captionTracks.isEmpty else { return }
            self.selectedSidecarCaptionIndex = 1
            self.reloadSidecarCues()
        }
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
        persistResumeBookmarkNow()
        if !usesEmbeddedWebPlayer, totalSeconds > 0, progressSeconds > 2 {
            let p = progressSeconds
            let d = totalSeconds
            Task {
                try? await learningRepository.saveWatchProgress(
                    programId: courseId,
                    moduleId: moduleId,
                    lessonId: lessonId,
                    positionSeconds: p,
                    durationSeconds: d
                )
            }
        }
        player.pause()
    }

    func selectSidecarCaptionIndex(_ index: Int) {
        let clamped = max(0, min(index, captionTracks.count))
        selectedSidecarCaptionIndex = clamped
        Task { @MainActor in self.reloadSidecarCues() }
    }

    func selectManifestCaptionMenuIndex(_ index: Int) {
        guard let group = manifestLegibleGroup else { return }
        let clamped = max(0, min(index, manifestLegibleOptions.count))
        manifestCaptionMenuIndex = clamped
        if manifestCaptionMenuIndex == 0 {
            player.currentItem?.selectMediaOptionAutomatically(in: group)
            return
        }
        let optIndex = manifestCaptionMenuIndex - 1
        guard optIndex < manifestLegibleOptions.count else { return }
        player.currentItem?.select(manifestLegibleOptions[optIndex], in: group)
    }

    func setQualityPreset(_ preset: HLSQualityPreset) {
        guard !usesEmbeddedWebPlayer else { return }
        qualityPreset = preset
        applyQualityPresetToCurrentItem()
    }

    private func tick(time: CMTime) {
        let current = CMTimeGetSeconds(time)
        progressSeconds = current.isFinite ? current : 0

        if let duration = player.currentItem?.duration, duration.isValid, !duration.isIndefinite {
            let total = CMTimeGetSeconds(duration)
            totalSeconds = total.isFinite && total > 0 ? total : 0
        }

        emitPlaybackHeartbeatIfNeeded()
        applyResumeBookmarkOnceIfReady()
        persistResumeBookmarkIfNeeded()
        flushWatchProgressToServerIfNeeded()
        updateSidecarOverlay()
    }

    private func updateStatus() {
        switch player.status {
        case .readyToPlay:
            if !didAttemptManifestCaptionLoad {
                didAttemptManifestCaptionLoad = true
                refreshManifestLegibleMenu()
            }
            if player.timeControlStatus != .playing {
                player.playImmediately(atRate: playbackRate)
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
            player.playImmediately(atRate: playbackRate)
            syncPlaybackState()
        }
    }

    func setPlaybackRate(_ rate: Float) {
        guard !usesEmbeddedWebPlayer else { return }
        let r = LessonVideoPlaybackPolicy.nearestPlaybackRate(to: rate)
        playbackRate = r
        player.defaultRate = r
        if player.timeControlStatus == .playing {
            player.rate = r
        }
    }

    func skip(by delta: Double) {
        guard !usesEmbeddedWebPlayer else { return }
        let cap = max(totalSeconds, 0)
        let target = min(cap, max(0, progressSeconds + delta))
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
    }

    func seek(toFraction fraction: Double) {
        guard !usesEmbeddedWebPlayer else { return }
        let clamped = min(1, max(0, fraction))
        let seconds = clamped * totalSeconds
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time)
    }

    func markLessonComplete() async {
        UserDefaults.standard.removeObject(
            forKey: LessonVideoPlaybackPolicy.resumeStorageKey(courseId: courseId, lessonId: lessonId)
        )
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
        guard sourceURL.host?.lowercased() == "commondatastorage.googleapis.com" else { return false }
        guard var components = URLComponents(url: sourceURL, resolvingAgainstBaseURL: false) else { return false }

        hasAttemptedHostRecovery = true
        components.host = "storage.googleapis.com"
        guard let rewritten = components.url else { return false }

        player.replaceCurrentItem(with: AVPlayerItem(url: rewritten))
        sourceURL = rewritten
        didAttemptManifestCaptionLoad = false
        configureCurrentItemForUdemyStylePlayback()
        player.playImmediately(atRate: playbackRate)
        syncPlaybackState()
        return true
    }

    private func configureCurrentItemForUdemyStylePlayback() {
        guard let item = player.currentItem else { return }
        item.audioTimePitchAlgorithm = .timeDomain
        applyQualityPresetToCurrentItem()
    }

    private func applyQualityPresetToCurrentItem() {
        guard let item = player.currentItem else { return }
        item.preferredMaximumResolution = qualityPreset.preferredMaximumResolution
        item.preferredPeakBitRate = 0
    }

    private func refreshManifestLegibleMenu() {
        guard !usesEmbeddedWebPlayer else { return }
        guard let asset = player.currentItem?.asset else { return }
        Task { [weak self] in
            let legibleGroup: AVMediaSelectionGroup?
            do {
                legibleGroup = try await Self.loadManifestLegibleGroup(from: asset)
            } catch {
                legibleGroup = nil
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                guard let legibleGroup else {
                    self.clearManifestLegibleMenu()
                    return
                }
                self.manifestLegibleGroup = legibleGroup
                self.manifestLegibleOptions = Array(legibleGroup.options)
                self.manifestCaptionMenuLabels = legibleGroup.options.compactMap { $0.displayName }
                self.manifestCaptionMenuIndex = 0
            }
        }
    }

    /// Resolves the manifest `.legible` selection group using async AVFoundation loading.
    ///
    /// We deliberately call `load(_:)` without the `isolation:` parameter so the same source compiles on
    /// Xcode 16.4 (where `AVAsyncProperty.load` has no `isolation:` overload) and on newer Xcodes (where the
    /// default `#isolation` value is fine for this `nonisolated` static helper).
    private static func loadManifestLegibleGroup(from asset: AVAsset) async throws -> AVMediaSelectionGroup? {
        let characteristics: [AVMediaCharacteristic] = try await asset.load(
            .availableMediaCharacteristicsWithMediaSelectionOptions
        )
        guard characteristics.contains(AVMediaCharacteristic.legible) else { return nil }
        return try await asset.loadMediaSelectionGroup(for: AVMediaCharacteristic.legible)
    }

    private func clearManifestLegibleMenu() {
        manifestLegibleGroup = nil
        manifestLegibleOptions = []
        manifestCaptionMenuLabels = []
        manifestCaptionMenuIndex = 0
    }

    private func reloadSidecarCues() {
        let index = selectedSidecarCaptionIndex
        guard index > 0, index <= captionTracks.count else {
            sidecarCues = []
            sidecarCaptionText = nil
            return
        }
        let track = captionTracks[index - 1]
        Task { [weak self] in
            let doc = await Self.fetchWebVTTDocument(for: track)
            await MainActor.run { [weak self] in
                guard let self else { return }
                guard let doc else {
                    self.sidecarCues = []
                    self.sidecarCaptionText = nil
                    return
                }
                self.sidecarCues = WebVTTParser.parseCues(from: doc)
            }
        }
    }

    private static func fetchWebVTTDocument(for track: LessonCaptionTrack) async -> String? {
        if track.webvttURL == "embedded:wcs-investor-en" {
            return InvestorDemoEmbeddedCaptions.englishDocument
        }
        guard let url = URL(string: track.webvttURL), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            return nil
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func updateSidecarOverlay() {
        guard selectedSidecarCaptionIndex > 0, !sidecarCues.isEmpty else {
            sidecarCaptionText = nil
            return
        }
        sidecarCaptionText = WebVTTParser.activeCue(for: progressSeconds, in: sidecarCues)
    }

    private func applyResumeBookmarkOnceIfReady() {
        guard !didApplyResumeBookmark, !usesEmbeddedWebPlayer else { return }
        guard let bookmark = resumeBookmarkSeconds else {
            didApplyResumeBookmark = true
            return
        }
        guard totalSeconds > 1 else { return }
        guard bookmark > 3, bookmark < totalSeconds - 2 else {
            didApplyResumeBookmark = true
            return
        }
        didApplyResumeBookmark = true
        player.seek(
            to: CMTime(seconds: bookmark, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        player.playImmediately(atRate: playbackRate)
    }

    private func persistResumeBookmarkIfNeeded() {
        guard !usesEmbeddedWebPlayer, totalSeconds > 0 else { return }
        let p = progressSeconds
        guard p > 3, p < totalSeconds - 2 else { return }
        let now = Date()
        guard now.timeIntervalSince(lastResumeWrite) >= 2 else { return }
        lastResumeWrite = now
        persistResumeBookmarkNow(position: p)
    }

    private func persistResumeBookmarkNow() {
        guard !usesEmbeddedWebPlayer, totalSeconds > 0 else { return }
        let p = progressSeconds
        guard p > 3, p < totalSeconds - 2 else { return }
        persistResumeBookmarkNow(position: p)
    }

    private func persistResumeBookmarkNow(position p: Double) {
        UserDefaults.standard.set(
            p,
            forKey: LessonVideoPlaybackPolicy.resumeStorageKey(courseId: courseId, lessonId: lessonId)
        )
    }

    private func flushWatchProgressToServerIfNeeded() {
        guard !usesEmbeddedWebPlayer, totalSeconds > 0 else { return }
        let p = progressSeconds
        guard p > 2 else { return }
        let now = Date()
        guard now.timeIntervalSince(lastServerWatchFlush) >= 3 else { return }
        lastServerWatchFlush = now
        let d = totalSeconds
        Task {
            try? await learningRepository.saveWatchProgress(
                programId: courseId,
                moduleId: moduleId,
                lessonId: lessonId,
                positionSeconds: p,
                durationSeconds: d
            )
        }
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
}
