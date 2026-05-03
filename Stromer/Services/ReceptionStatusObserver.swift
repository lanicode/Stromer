import Foundation
import Observation
import StromerScanner

enum ReceptionStatus: Equatable {
    case live
    case waiting
    case offline
}

@MainActor
@Observable
final class ReceptionStatusObserver {
    private(set) var status: ReceptionStatus = .waiting

    private var lastReadingAt: Date?
    private var timer: Timer?
    private let nowProvider: () -> Date

    init(nowProvider: @escaping () -> Date = Date.init) {
        self.nowProvider = nowProvider
    }

    func handleReading(_ reading: DeviceReading) {
        handleReading(at: reading.timestamp)
    }

    func handleReading(at timestamp: Date?) {
        lastReadingAt = timestamp
        recompute()
    }

    func seed(lastReadingAt timestamp: Date?) {
        guard let timestamp else {
            recompute()
            return
        }

        if let current = lastReadingAt, current >= timestamp {
            recompute()
            return
        }

        lastReadingAt = timestamp
        recompute()
    }

    func recompute() {
        recompute(now: nowProvider())
    }

    func recompute(now: Date) {
        guard let lastReadingAt else {
            status = .waiting
            return
        }

        let elapsed = now.timeIntervalSince(lastReadingAt)
        switch elapsed {
        case 0..<30:
            status = .live
        case 30..<300:
            status = .waiting
        default:
            status = .offline
        }
    }

    func startTicking() {
        guard timer == nil else {
            return
        }

        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.recompute()
            }
        }
    }

    func stopTicking() {
        timer?.invalidate()
        timer = nil
    }
}
