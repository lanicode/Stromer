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
    private let nowProvider: () -> Date
    private let reloadHandler: @MainActor () -> Void
    private let readingDebounceInterval: TimeInterval

    /// Creates a coordinator that debounces frequent reading reloads to preserve iOS widget reload budget.
    /// - Parameters:
    ///   - readingDebounceInterval: Minimum interval between reading-triggered widget reloads.
    init(
        nowProvider: @escaping () -> Date = Date.init,
        reloadHandler: @escaping @MainActor () -> Void = WidgetRefreshCoordinator.reloadStromerWidgetTimelines,
        readingDebounceInterval: TimeInterval = 180
    ) {
        self.nowProvider = nowProvider
        self.reloadHandler = reloadHandler
        self.readingDebounceInterval = readingDebounceInterval
    }

    deinit {
        pendingReadingReloadTask?.cancel()
    }

    func requestReload(reason: ReloadReason) {
        switch reason {
        case .reading:
            let now = nowProvider()
            if let lastReloadAt,
               now.timeIntervalSince(lastReloadAt) < readingDebounceInterval {
                scheduleTrailingReadingReload(after: readingDebounceInterval - now.timeIntervalSince(lastReloadAt))
                return
            }
            performReload(at: now)
        case .background, .foreground, .deviceRegistered, .deviceDeleted:
            pendingReadingReloadTask?.cancel()
            pendingReadingReloadTask = nil
            performReload(at: nowProvider())
        }
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

    private static func reloadStromerWidgetTimelines() {
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }
}
