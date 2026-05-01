import Foundation

public enum DeviceFreshness: String, Codable, CaseIterable, Equatable, Sendable {
    case fresh
    case delayed
    case stale
    case missing

    public static let freshUpperBound: TimeInterval = 120
    public static let delayedUpperBound: TimeInterval = 600
    public static let staleUpperBound: TimeInterval = 86_400

    public init(lastSeenAt: Date?, now: Date) {
        guard let lastSeenAt else {
            self = .missing
            return
        }

        let age = max(0, now.timeIntervalSince(lastSeenAt))

        if age < Self.freshUpperBound {
            self = .fresh
        } else if age < Self.delayedUpperBound {
            self = .delayed
        } else if age <= Self.staleUpperBound {
            self = .stale
        } else {
            self = .missing
        }
    }
}
