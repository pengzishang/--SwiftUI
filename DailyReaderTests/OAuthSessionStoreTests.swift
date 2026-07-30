import Security
import XCTest
@testable import DailyReader

final class OAuthSessionStoreTests: XCTestCase {
    func testSaveUsesExactAuthenticationNamespaceAndDeviceOnlyAccessibility() async throws {
        let client = CapturingKeychainClient()
        let store = KeychainAuthSessionStore(client: client, service: "test.auth.service")
        let token = try OAuthTokenSet(accessToken: "synthetic", refreshToken: nil, tokenType: "Bearer", expiresAt: nil, grantedScopes: [])

        try await store.save(StoredAuthSession(tokenSet: token))

        let add = client.added
        XCTAssertEqual(add?[kSecAttrService as String] as? String, "test.auth.service")
        XCTAssertEqual(add?[kSecAttrAccount as String] as? String, KeychainAuthSessionStore.account)
        XCTAssertEqual(add?[kSecAttrAccessible as String] as! CFString, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
        XCTAssertEqual(add?[kSecAttrSynchronizable as String] as? Bool, false)
    }

    func testDeleteQueryCannotMatchExistingReadingKeys() async throws {
        let client = CapturingKeychainClient()
        let store = KeychainAuthSessionStore(client: client, service: "test.auth.service")
        try await store.delete()

        let query = client.deleted
        XCTAssertEqual(query?[kSecAttrService as String] as? String, "test.auth.service")
        XCTAssertEqual(query?[kSecAttrAccount as String] as? String, "session.current")
        XCTAssertNotEqual(query?[kSecAttrAccount as String] as? String, "DailyReader.favoriteStories")
    }
}

private final class CapturingKeychainClient: KeychainSecItemClient, @unchecked Sendable {
    var added: [String: Any]?
    var deleted: [String: Any]?

    func copyMatching(_ query: CFDictionary, result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus { errSecItemNotFound }
    func add(_ attributes: CFDictionary) -> OSStatus {
        added = attributes as? [String: Any]
        return errSecSuccess
    }
    func update(_ query: CFDictionary, attributes: CFDictionary) -> OSStatus { errSecItemNotFound }
    func delete(_ query: CFDictionary) -> OSStatus {
        deleted = query as? [String: Any]
        return errSecItemNotFound
    }
}
