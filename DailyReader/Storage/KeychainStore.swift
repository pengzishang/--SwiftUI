import Foundation
import Security

protocol KeychainSecItemClient: Sendable {
    func copyMatching(_ query: CFDictionary, result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
    func add(_ attributes: CFDictionary) -> OSStatus
    func update(_ query: CFDictionary, attributes: CFDictionary) -> OSStatus
    func delete(_ query: CFDictionary) -> OSStatus
}

struct SystemKeychainSecItemClient: KeychainSecItemClient {
    func copyMatching(_ query: CFDictionary, result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        SecItemCopyMatching(query, result)
    }

    func add(_ attributes: CFDictionary) -> OSStatus { SecItemAdd(attributes, nil) }
    func update(_ query: CFDictionary, attributes: CFDictionary) -> OSStatus { SecItemUpdate(query, attributes) }
    func delete(_ query: CFDictionary) -> OSStatus { SecItemDelete(query) }
}

enum KeychainStoreError: Error, Equatable {
    case status(OSStatus)
    case corruptData
    case ambiguousLegacyItems
    case migrationVerificationFailed
}

struct KeychainDataStore: @unchecked Sendable {
    private let client: any KeychainSecItemClient
    let service: String

    init(
        service: String,
        client: any KeychainSecItemClient = SystemKeychainSecItemClient()
    ) {
        self.service = service
        self.client = client
    }

    func read(account: String, migrateLegacy: Bool = true) throws -> Data? {
        if let data = try readNamespaced(account: account) {
            return data
        }
        guard migrateLegacy, let legacy = try readLegacy(account: account) else {
            return nil
        }

        try save(legacy.data, account: account)
        guard try readNamespaced(account: account) == legacy.data else {
            throw KeychainStoreError.migrationVerificationFailed
        }
        try deleteLegacy(persistentReference: legacy.persistentReference)
        return legacy.data
    }

    func save(_ data: Data, account: String) throws {
        let query = baseQuery(account: account)
        let updateStatus = client.update(
            query as CFDictionary,
            attributes: [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainStoreError.status(updateStatus)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = client.add(addQuery as CFDictionary)
        guard addStatus == errSecSuccess else {
            throw KeychainStoreError.status(addStatus)
        }
    }

    func delete(account: String) throws {
        let status = client.delete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.status(status)
        }
    }

    func deleteLegacy(account: String) throws {
        guard let legacy = try readLegacy(account: account) else { return }
        try deleteLegacy(persistentReference: legacy.persistentReference)
    }

    private func readNamespaced(account: String) throws -> Data? {
        var result: CFTypeRef?
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        let status = client.copyMatching(query as CFDictionary, result: &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainStoreError.status(status) }
        guard let data = result as? Data else { throw KeychainStoreError.corruptData }
        return data
    }

    private func readLegacy(account: String) throws -> LegacyItem? {
        var result: CFTypeRef?
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecReturnPersistentRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        let status = client.copyMatching(query as CFDictionary, result: &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainStoreError.status(status) }

        let items: [[String: Any]]
        if let array = result as? [[String: Any]] {
            items = array
        } else if let item = result as? [String: Any] {
            items = [item]
        } else {
            throw KeychainStoreError.corruptData
        }
        guard items.count == 1 else { throw KeychainStoreError.ambiguousLegacyItems }
        guard let data = items[0][kSecValueData as String] as? Data,
              let persistentReference = items[0][kSecValuePersistentRef as String] as? Data else {
            throw KeychainStoreError.corruptData
        }
        return LegacyItem(data: data, persistentReference: persistentReference)
    }

    private func deleteLegacy(persistentReference: Data) throws {
        let status = client.delete([
            kSecClass as String: kSecClassGenericPassword,
            kSecValuePersistentRef as String: persistentReference
        ] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.status(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false
        ]
    }
}

private struct LegacyItem {
    let data: Data
    let persistentReference: Data
}
