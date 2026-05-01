import Foundation
import Security

public final class KeychainStore: KeychainStoring, @unchecked Sendable {
    public let service: String
    public let accessGroup: String?
    private let accessible: CFString

    public init(
        service: String = StromerIdentifiers.keychainService,
        accessGroup: String? = StromerIdentifiers.appGroup,
        accessible: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ) {
        self.service = service
        self.accessGroup = accessGroup
        self.accessible = accessible
    }

    public func saveKey(_ key: Data, for account: String) throws {
        try deleteKey(for: account, allowMissing: true)

        var attributes = baseQuery(account: account)
        attributes[kSecValueData as String] = key
        attributes[kSecAttrAccessible as String] = accessible

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw ScannerError.keychainFailed(status: status)
        }
    }

    public func loadKey(for account: String) throws -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw ScannerError.keychainFailed(status: status)
        }

        return item as? Data
    }

    public func deleteKey(for account: String) throws {
        try deleteKey(for: account, allowMissing: false)
    }

    private func deleteKey(for account: String, allowMissing: Bool) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        if status == errSecItemNotFound, allowMissing {
            return
        }

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ScannerError.keychainFailed(status: status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }
}
