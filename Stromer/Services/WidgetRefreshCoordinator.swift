import Foundation
import WidgetKit

@MainActor
final class WidgetRefreshCoordinator {
    enum ReloadReason {
        case reading
        case background
        case foreground
        case deviceRegistered
        case deviceDeleted
    }

    private static let widgetKind = "StromerWidget"

    private var lastReloadAt: Date?
    private var pendingReadingReloadTask: Task<Void, Never>?
    private var backgroundGraceTask: Task<Void, Never>?
    private var isInBackgroundGrace = false
    private let nowProvider: () -> Date
    private let reloadHandler: @MainActor () -> Void
    private let readingDebounceInterval: TimeInterval
    private let backgroundGraceDebounceInterval: TimeInterval
    private let backgroundGraceDuration: TimeInterval

    /// Creates a coordinator that debounces frequent reading reloads to preserve iOS widget reload budget.
    /// - Parameters:
    ///   - readingDebounceInterval: Minimum interval between reading-triggered widget reloads.
    ///   - backgroundGraceDebounceInterval: Shorter reading debounce used while iOS may still deliver BLE advertisements after backgrounding.
    ///   - backgroundGraceDuration: Duration of the shorter background grace debounce window.
    init(
        nowProvider: @escaping () -> Date = Date.init,
        reloadHandler: @escaping @MainActor () -> Void = WidgetRefreshCoordinator.reloadStromerWidgetTimelines,
        readingDebounceInterval: TimeInterval = 180,
        backgroundGraceDebounceInterval: TimeInterval = 30,
        backgroundGraceDuration: TimeInterval = 180
    ) {
        self.nowProvider = nowProvider
        self.reloadHandler = reloadHandler
        self.readingDebounceInterval = readingDebounceInterval
        self.backgroundGraceDebounceInterval = backgroundGraceDebounceInterval
        self.backgroundGraceDuration = backgroundGraceDuration
    }

    deinit {
        pendingReadingReloadTask?.cancel()
        backgroundGraceTask?.cancel()
    }

    func requestReload(reason: ReloadReason) {
        switch reason {
        case .reading:
            let now = nowProvider()
            let debounceInterval = effectiveReadingDebounceInterval
            if let lastReloadAt,
               now.timeIntervalSince(lastReloadAt) < debounceInterval {
                scheduleTrailingReadingReload(after: debounceInterval - now.timeIntervalSince(lastReloadAt))
                return
            }
            performReload(at: now)
        case .background:
            pendingReadingReloadTask?.cancel()
            pendingReadingReloadTask = nil
            performReload(at: nowProvider())
            startBackgroundGraceWindow()
        case .foreground, .deviceRegistered, .deviceDeleted:
            pendingReadingReloadTask?.cancel()
            pendingReadingReloadTask = nil
            performReload(at: nowProvider())
            endBackgroundGraceWindow()
        }
    }

    private var effectiveReadingDebounceInterval: TimeInterval {
        isInBackgroundGrace ? backgroundGraceDebounceInterval : readingDebounceInterval
    }

    private func performReload(at date: Date) {
        reloadHandler()
        lastReloadAt = date
    }

    private func scheduleTrailingReadingReload(after delay: TimeInterval) {
        guard pendingReadingReloadTask == nil else {
            return
        }

        pendingReadingReloadTask = Task { [weak self] in
            let nanoseconds = Int64(max(0, delay) * 1_000_000_000)
            try? await Task.sleep(for: .nanoseconds(nanoseconds))

            await MainActor.run {
                guard let self else {
                    return
                }

                self.pendingReadingReloadTask = nil
                self.performReload(at: self.nowProvider())
            }
        }
    }

    private func startBackgroundGraceWindow() {
        isInBackgroundGrace = true
        backgroundGraceTask?.cancel()
        let duration = backgroundGraceDuration
        backgroundGraceTask = Task { [weak self] in
            let nanoseconds = Int64(max(0, duration) * 1_000_000_000)
            try? await Task.sleep(for: .nanoseconds(nanoseconds))

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard let self else {
                    return
                }

                self.isInBackgroundGrace = false
                self.backgroundGraceTask = nil
            }
        }
    }

    private func endBackgroundGraceWindow() {
        isInBackgroundGrace = false
        backgroundGraceTask?.cancel()
        backgroundGraceTask = nil
    }

    private static func reloadStromerWidgetTimelines() {
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }
}
