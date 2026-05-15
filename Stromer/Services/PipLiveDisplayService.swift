import AVFoundation
import AVKit
import CoreMedia
import Observation
import StromerScanner
import SwiftUI

@MainActor
@Observable
final class PipLiveDisplayService: NSObject {
    private(set) var isPipActive = false
    private(set) var lastError: String?
    private(set) var renderSize: CGSize = CGSize(width: 320, height: 180)

    var isSupported: Bool {
        supportProvider()
    }

    @ObservationIgnored private let metrics: PipDebugMetrics
    @ObservationIgnored private let frameRenderer: PipFrameRenderer
    @ObservationIgnored private let snapshotProvider: @MainActor () -> StromerWidgetSnapshot?
    @ObservationIgnored private let supportProvider: () -> Bool
    @ObservationIgnored private let nowProvider: () -> Date
    @ObservationIgnored private(set) var displayLayer: AVSampleBufferDisplayLayer?
    @ObservationIgnored private var pipController: AVPictureInPictureController?
    @ObservationIgnored private var warmUpTask: Task<Void, Never>?
    @ObservationIgnored private var frameLoopTask: Task<Void, Never>?
    @ObservationIgnored private var startedAt: Date?
    @ObservationIgnored private var lastFrameRenderedAt: Date?

    private static let snapshotProviderUnavailableError = "PiP-Snapshot-Provider nicht verfügbar."

    init(
        metrics: PipDebugMetrics,
        frameRenderer: PipFrameRenderer? = nil,
        snapshotProvider: @escaping @MainActor () -> StromerWidgetSnapshot? = { nil },
        supportProvider: @escaping () -> Bool = AVPictureInPictureController.isPictureInPictureSupported,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.metrics = metrics
        self.frameRenderer = frameRenderer ?? PipFrameRenderer()
        self.snapshotProvider = snapshotProvider
        self.supportProvider = supportProvider
        self.nowProvider = nowProvider
    }

    deinit {
        warmUpTask?.cancel()
        frameLoopTask?.cancel()
    }

    func attachDisplayLayer(_ layer: AVSampleBufferDisplayLayer) {
        layer.frame = CGRect(origin: .zero, size: renderSize)
        layer.videoGravity = .resizeAspect
        displayLayer = layer
        configurePictureInPictureIfNeeded()
    }

    func start() {
        guard isSupported else {
            lastError = "PiP nicht unterstützt."
            return
        }

        guard displayLayer != nil else {
            lastError = "PiP-Display-Layer nicht verbunden."
            return
        }

        lastError = nil
        startedAt = nowProvider()

        do {
            try configureAudioSession(active: true)
        } catch {
            lastError = "AVAudioSession konnte nicht aktiviert werden: \(error.localizedDescription)"
            return
        }

        configurePictureInPictureIfNeeded()
        renderFrame(force: true)
        startFrameLoop()

        guard let pipController else {
            lastError = "PiP-Controller konnte nicht erstellt werden."
            stop()
            return
        }

        if pipController.isPictureInPictureActive {
            isPipActive = true
            return
        }

        stopWarmUpTask()
        warmUpTask = Task { @MainActor [weak self] in
            await self?.enqueueWarmUpFrames()
            guard !Task.isCancelled,
                  let self,
                  let pipController = self.pipController else {
                return
            }

            if pipController.isPictureInPictureActive {
                self.isPipActive = true
                return
            }

            pipController.startPictureInPicture()
        }
    }

    func stop() {
        stopWarmUpTask()
        stopFrameLoop()

        if pipController?.isPictureInPictureActive == true {
            pipController?.stopPictureInPicture()
        }

        isPipActive = false
        startedAt = nil
        deactivateAudioSession()
    }

    func renderReadingUpdate() {
        guard isPipActive || frameLoopTask != nil else {
            return
        }

        renderFrame(force: false)
    }

    private func enqueueWarmUpFrames() async {
        for frameIndex in 0..<3 {
            guard !Task.isCancelled else {
                return
            }

            renderFrame(force: true)

            guard frameIndex < 2 else {
                continue
            }

            do {
                try await Task.sleep(for: .milliseconds(80))
            } catch {
                return
            }
        }
    }

    private func stopWarmUpTask() {
        warmUpTask?.cancel()
        warmUpTask = nil
    }

    private func configurePictureInPictureIfNeeded() {
        guard pipController == nil else {
            return
        }

        guard let displayLayer else {
            return
        }

        let contentSource = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: displayLayer,
            playbackDelegate: self
        )
        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.delegate = self
        controller.requiresLinearPlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = false
        pipController = controller
    }

    private func configureAudioSession(active: Bool) throws {
        let audioSession = AVAudioSession.sharedInstance()
        if active {
            try audioSession.setCategory(.playback, options: [.mixWithOthers])
        }
        try audioSession.setActive(active)
    }

    private func deactivateAudioSession() {
        do {
            try configureAudioSession(active: false)
        } catch {
            lastError = "AVAudioSession konnte nicht deaktiviert werden: \(error.localizedDescription)"
        }
    }

    private func startFrameLoop() {
        stopFrameLoop()
        frameLoopTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.renderFrame(force: true)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func stopFrameLoop() {
        frameLoopTask?.cancel()
        frameLoopTask = nil
    }

    private func renderFrame(force: Bool) {
        let now = nowProvider()
        if !force,
           let lastFrameRenderedAt,
           now.timeIntervalSince(lastFrameRenderedAt) < 1 {
            return
        }

        guard let displayLayer else {
            return
        }

        let snapshot = snapshotProvider()
        if snapshot == nil,
           lastError == nil || lastError == Self.snapshotProviderUnavailableError {
            lastError = Self.snapshotProviderUnavailableError
        }
        let dashboardData = snapshot.map {
            PipDashboardData.from(snapshot: $0, now: now)
        } ?? .empty()
        let elapsedSeconds = Int(now.timeIntervalSince(startedAt ?? now))
        let view = PipLiveDashboard(
            primaryValue: dashboardData.primaryValue,
            primaryUnit: dashboardData.primaryUnit,
            primaryLabel: dashboardData.primaryLabel,
            secondaryValue: dashboardData.secondaryValue,
            secondaryLabel: dashboardData.secondaryLabel,
            relativeUpdatedText: dashboardData.relativeUpdatedText,
            isStale: dashboardData.isStale,
            elapsedSeconds: elapsedSeconds,
            readsTotal: metrics.readsTotal
        )

        guard let sampleBuffer = frameRenderer.render(view, size: renderSize) else {
            lastError = frameRenderer.errorMessage ?? "PiP-Frame konnte nicht erstellt werden."
            return
        }

        displayLayer.sampleBufferRenderer.enqueue(sampleBuffer)
        pipController?.invalidatePlaybackState()
        lastFrameRenderedAt = now
    }
}

extension PipLiveDisplayService: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerWillStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        Task { @MainActor [weak self] in
            self?.lastError = nil
        }
    }

    nonisolated func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        Task { @MainActor [weak self] in
            self?.isPipActive = true
            self?.lastError = nil
        }
    }

    nonisolated func pictureInPictureControllerWillStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        Task { @MainActor [weak self] in
            self?.isPipActive = false
        }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        Task { @MainActor [weak self] in
            self?.isPipActive = false
            self?.stopWarmUpTask()
            self?.stopFrameLoop()
            self?.startedAt = nil
            self?.deactivateAudioSession()
        }
    }

    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            self?.isPipActive = false
            self?.lastError = "PiP konnte nicht gestartet werden: \(message)"
            self?.stopWarmUpTask()
            self?.stopFrameLoop()
            self?.deactivateAudioSession()
        }
    }
}

extension PipLiveDisplayService: AVPictureInPictureSampleBufferPlaybackDelegate {
    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        setPlaying playing: Bool
    ) {
    }

    nonisolated func pictureInPictureControllerTimeRangeForPlayback(
        _ pictureInPictureController: AVPictureInPictureController
    ) -> CMTimeRange {
        CMTimeRange(start: .zero, duration: .positiveInfinity)
    }

    nonisolated func pictureInPictureControllerIsPlaybackPaused(
        _ pictureInPictureController: AVPictureInPictureController
    ) -> Bool {
        false
    }

    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        didTransitionToRenderSize newRenderSize: CMVideoDimensions
    ) {
        Task { @MainActor [weak self] in
            // Keep the custom PiP source fixed at 320x180; iOS scales it through videoGravity.
            // Changing the source size during PiP resize can produce cropped or black frames.
            self?.renderFrame(force: true)
        }
    }

    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        skipByInterval skipInterval: CMTime,
        completion: @escaping () -> Void
    ) {
        completion()
    }
}
