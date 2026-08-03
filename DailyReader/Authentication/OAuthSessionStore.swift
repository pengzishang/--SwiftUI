import Foundation
import Security

protocol AuthSessionStoring: Sendable {
    func load() async throws -> StoredAuthSession?
    func save(_ session: StoredAuthSession) async throws
    func delete() async throws
}

actor KeychainAuthSessionStore: AuthSessionStoring {
    static let service = "com.codex.DailyReader.auth.zhihu.oauth.v1"
    static let account = "session.current"

    private let client: any KeychainSecItemClient
    private let service: String
    private let account: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        client: any KeychainSecItemClient = SystemKeychainSecItemClient(),
        service: String = KeychainAuthSessionStore.service,
        account: String = KeychainAuthSessionStore.account
    ) {
        self.client = client
        self.service = service
        self.account = account
    }

    func load() async throws -> StoredAuthSession? {
        var result: CFTypeRef?
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        let status = client.copyMatching(query as CFDictionary, result: &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainStoreError.status(status) }
        guard let data = result as? Data,
              let session = try? decoder.decode(StoredAuthSession.self, from: data),
              session.schemaVersion == StoredAuthSession.currentSchemaVersion else {
            try await delete()
            throw KeychainStoreError.corruptData
        }
        return session
    }

    func save(_ session: StoredAuthSession) async throws {
        let data = try encoder.encode(session)
        let updateStatus = client.update(
            baseQuery as CFDictionary,
            attributes: [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw KeychainStoreError.status(updateStatus) }
        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        addQuery[kSecAttrSynchronizable as String] = false
        let addStatus = client.add(addQuery as CFDictionary)
        guard addStatus == errSecSuccess else { throw KeychainStoreError.status(addStatus) }
    }

    func delete() async throws {
        let status = client.delete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.status(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false
        ]
    }
}

actor InMemoryAuthSessionStore: AuthSessionStoring {
    private var session: StoredAuthSession?

    init(session: StoredAuthSession? = nil) { self.session = session }
    func load() async throws -> StoredAuthSession? { session }
    func save(_ session: StoredAuthSession) async throws { self.session = session }
    func delete() async throws { session = nil }
}
