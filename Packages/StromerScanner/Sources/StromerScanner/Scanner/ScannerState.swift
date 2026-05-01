import Foundation

public enum ScannerState: Equatable, Sendable {
    case idle
    case scanning
    case unauthorized
    case off
    case unsupported
    case resetting
    case unknown
    case failed(String)
}
