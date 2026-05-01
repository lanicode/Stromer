import Foundation

public enum DiscoverySupportStatus: String, Codable, Equatable, Sendable {
    case supported
    case plannedPhase37
    case outOfScope

    public var title: String {
        switch self {
        case .supported:
            return "Unterstützt"
        case .plannedPhase37:
            return "Folgt später"
        case .outOfScope:
            return "Nicht unterstützt"
        }
    }
}
