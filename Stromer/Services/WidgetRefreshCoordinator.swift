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

    private static let debounceInterval: TimeInterval = 30

    private var lastReloadAt: Date?
    private let nowProvider: () -> Date
    private let reloadHandler: () -> Void

    init(
        nowProvider: @escaping () -> Date = Date.init,
        reloadHandler: @escaping () -> Void = {
            WidgetCenter.shared.reloadAllTimelines()
        }
    ) {
        self.nowProvider = nowProvider
        self.reloadHandler = reloadHandler
    }

    func requestReload(reason: ReloadReason) {
        switch reason {
        case .reading:
            let now = nowProvider()
            if let lastReloadAt,
               now.timeIntervalSince(lastReloadAt) < Self.debounceInterval {
                return
            }
            performReload(at: now)
        case .background, .foreground, .deviceRegistered, .deviceDeleted:
            performReload(at: nowProvider())
        }
    }

    private func performReload(at date: Date) {
        reloadHandler()
        lastReloadAt = date
    }
}
