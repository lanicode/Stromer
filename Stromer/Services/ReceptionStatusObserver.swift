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
    enum ConnectionStatus: Equatable {
        case live
        case recent
        case stale
        case offline
        case waiting

        var label: String {
            switch self {
            case .live:
                return "LIVE"
            case .recent:
                return "AKTUELL"
            case .stale:
                return "VERALTET"
            case .offline:
                return "OFFLINE"
            case .waiting:
                return "WARTET"
            }
        }

        var dimsLiveValue: Bool {
            self == .stale || self == .offline
        }
    }

    private(set) var status: ReceptionStatus = .waiting

    private var lastReadingAt: Date?
    private var deviceLastSeen: [UUID: Date] = [:]
    private var deviceStatuses: [UUID: ConnectionStatus] = [:]
    private var timer: Timer?
    private let nowProvider: () -> Date

    init(nowProvider: @escaping () -> Date = Date.init) {
        self.nowProvider = nowProvider
    }

    func handleReading(_ reading: DeviceReading) {
        deviceLastSeen[reading.deviceID] = reading.timestamp
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

    func seed(deviceLastSeen timestamps: [UUID: Date]) {
        for (deviceID, timestamp) in timestamps {
            if let current = deviceLastSeen[deviceID], current >= timestamp {
                continue
            }
            deviceLastSeen[deviceID] = timestamp
        }
        recompute()
    }

    func seed(deviceID: UUID, lastSeenAt timestamp: Date?) {
        guard let timestamp else {
            recompute()
            return
        }

        if let current = deviceLastSeen[deviceID], current >= timestamp {
            recompute()
            return
        }

        deviceLastSeen[deviceID] = timestamp
        recompute()
    }

    func status(for deviceID: UUID) -> ConnectionStatus {
        deviceStatuses[deviceID] ?? .waiting
    }

    func lastSeen(for deviceID: UUID) -> Date? {
        deviceLastSeen[deviceID]
    }

    func relativeTimeText(for deviceID: UUID) -> String {
        guard let lastSeen = deviceLastSeen[deviceID] else {
            return "Noch keine Daten"
        }

        let elapsed = max(0, nowProvider().timeIntervalSince(lastSeen))
        switch elapsed {
        case 0..<30:
            return "gerade eben"
        case 30..<60:
            return "vor weniger als 1 Min"
        case 60..<3_600:
            return "vor \(Int(elapsed / 60)) Min"
        case 3_600..<86_400:
            return "vor \(Int(elapsed / 3_600)) Std"
        default:
            return "vor \(Int(elapsed / 86_400)) Tagen"
        }
    }

    func recompute() {
        recompute(now: nowProvider())
    }

    func recompute(now: Date) {
        if let lastReadingAt {
            let elapsed = now.timeIntervalSince(lastReadingAt)
            switch elapsed {
            case 0..<30:
                status = .live
            case 30..<300:
                status = .waiting
            default:
                status = .offline
            }
        } else {
            status = .waiting
        }

        for (deviceID, lastSeen) in deviceLastSeen {
            let elapsed = now.timeIntervalSince(lastSeen)
            let connectionStatus: ConnectionStatus
            switch elapsed {
            case 0..<30:
                connectionStatus = .live
            case 30..<300:
                connectionStatus = .recent
            case 300..<3_600:
                connectionStatus = .stale
            default:
                connectionStatus = .offline
            }
            deviceStatuses[deviceID] = connectionStatus
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
