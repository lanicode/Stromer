import Foundation

public protocol KeychainStoring: Sendable {
    func saveKey(_ key: Data, for account: String) throws
    func loadKey(for account: String) throws -> Data?
    func deleteKey(for account: String) throws
}
