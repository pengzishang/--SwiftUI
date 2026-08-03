import Foundation

protocol ReadingStateBackingUp: Sendable {
    func read(account: String) throws -> Data?
    func save(_ data: Data, account: String) throws
    func delete(account: String) throws
}

struct KeychainReadingStateBackup: ReadingStateBackingUp, @unchecked Sendable {
    static let service = "com.codex.DailyReader.reading-state.v1"

    private let store: KeychainDataStore

    init(client: any KeychainSecItemClient = SystemKeychainSecItemClient()) {
        store = KeychainDataStore(service: Self.service, client: client)
    }

    func read(account: String) throws -> Data? {
        try store.read(account: account)
    }

    func save(_ data: Data, account: String) throws {
        try store.save(data, account: account)
    }

    func delete(account: String) throws {
        try store.delete(account: account)
    }
}
