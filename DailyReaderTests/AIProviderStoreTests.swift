import XCTest
@testable import DailyReader

@MainActor
final class AIProviderStoreTests: XCTestCase {
    func testUserProviderStartsBeforeDefaultServiceAndCanMove() throws {
        let fixture = try makeStore()
        let store = fixture.store
        try store.saveUserProvider(
            configuration: configuration(endpoint: "https://user.example.com/v1", model: "user-model"),
            apiKey: "user-key"
        )

        XCTAssertEqual(store.providers.map(\.id), [AIConfigurationStore.userProviderID, AIConfigurationStore.defaultProviderID])

        store.moveProviders(fromOffsets: IndexSet(integer: 0), toOffset: 2)

        XCTAssertEqual(store.providers.map(\.id), [AIConfigurationStore.defaultProviderID, AIConfigurationStore.userProviderID])
    }

    func testAllLogicalProvidersCanBeDisabled() throws {
        let fixture = try makeStore()
        let store = fixture.store
        for provider in store.providers {
            store.setEnabled(false, providerID: provider.id)
        }

        XCTAssertFalse(store.isReady)
        XCTAssertEqual(store.enabledProviderCount, 0)
        XCTAssertTrue(store.runtimeProviders().isEmpty)
    }

    func testDefaultServiceExpandsToThreeRuntimeLanesButCountsAsOneService() throws {
        let fixture = try makeStore()
        let runtime = fixture.store.runtimeProviders()

        XCTAssertEqual(fixture.store.enabledProviderCount, 1)
        XCTAssertEqual(fixture.store.enabledProviderSummary, "1 个服务")
        XCTAssertEqual(runtime.count, 3)
        XCTAssertEqual(Set(runtime.map(\.providerID)), [AIConfigurationStore.defaultProviderID])
        XCTAssertEqual(Set(runtime.map(\.providerName)), ["默认服务"])
        XCTAssertEqual(runtime.map(\.laneID), ["online", "sensenova_gou", "eric"])
        XCTAssertEqual(runtime.map(\.apiKey), ["online-key", "gou-key", "eric-key"])
    }

    func testDisabledProviderCanExpandOnlyForExplicitConnectionTest() throws {
        let fixture = try makeStore()
        fixture.store.setEnabled(false, providerID: AIConfigurationStore.defaultProviderID)

        XCTAssertTrue(fixture.store.runtimeProviders().isEmpty)
        XCTAssertEqual(
            fixture.store.runtimeProviders(
                providerID: AIConfigurationStore.defaultProviderID,
                includeDisabled: true
            ).count,
            3
        )
    }

    func testRuntimeLanesDeduplicateSameNormalizedEndpointModelAndCredential() throws {
        let credentials = InMemoryProviderCredentialStore(values: [
            "online": "shared-key",
            "eric": "shared-key"
        ])
        let name = "AIProviderStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let store = AIConfigurationStore(
            defaults: defaults,
            credentialStore: credentials,
            builtInProviders: [
                defaultProfile(lanes: [
                    lane(id: "online", endpoint: "https://example.com/v1", model: "same-model"),
                    lane(id: "eric", endpoint: "https://EXAMPLE.com/v1/chat/completions", model: "same-model")
                ])
            ]
        )
        defer { defaults.removePersistentDomain(forName: name) }

        XCTAssertEqual(store.runtimeProviders().map(\.laneID), ["online"])
    }

    func testMigratesFlatV2BuiltInsIntoOneDefaultServiceAndPreservesLaneCredentials() throws {
        let name = "AIProviderStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let credentials = InMemoryProviderCredentialStore(values: [
            AIConfigurationStore.userProviderID: "user-key",
            "online": "online-key",
            "sensenova_gou": "gou-key",
            "eric": "eric-key"
        ])
        defaults.set(
            try JSONEncoder().encode([
                LegacyProviderFixture(
                    id: AIConfigurationStore.userProviderID,
                    name: "我的服务",
                    configuration: configuration(endpoint: "https://user.example.com/v1", model: "user-model"),
                    source: .user,
                    isEnabled: true
                ),
                LegacyProviderFixture(id: "online", name: "ONLINE", configuration: configuration(model: "model-a"), source: .builtIn, isEnabled: false),
                LegacyProviderFixture(id: "sensenova_gou", name: "SENSENOVA_GOU", configuration: configuration(model: "model-b"), source: .builtIn, isEnabled: true),
                LegacyProviderFixture(id: "eric", name: "ERIC", configuration: configuration(model: "model-c"), source: .builtIn, isEnabled: false)
            ]),
            forKey: "DailyReader.ai.providers.v2"
        )

        let store = AIConfigurationStore(
            defaults: defaults,
            credentialStore: credentials,
            builtInProviders: [defaultProfile()]
        )
        defer { defaults.removePersistentDomain(forName: name) }

        XCTAssertEqual(store.providers.map(\.id), [AIConfigurationStore.userProviderID, AIConfigurationStore.defaultProviderID])
        XCTAssertTrue(store.providers[1].isEnabled)
        XCTAssertEqual(store.providers[1].lanes.map(\.id), ["online", "sensenova_gou", "eric"])
        XCTAssertNotNil(defaults.data(forKey: "DailyReader.ai.providers.v3"))
        XCTAssertEqual(try credentials.loadAPIKey(providerID: "online"), "online-key")
        XCTAssertEqual(try credentials.loadAPIKey(providerID: "sensenova_gou"), "gou-key")
        XCTAssertEqual(try credentials.loadAPIKey(providerID: "eric"), "eric-key")
        XCTAssertNil(try credentials.loadAPIKey(providerID: AIConfigurationStore.defaultProviderID))
    }

    func testRemovedBuiltInLaneCredentialIsDeletedDuringInstallation() throws {
        let credentials = InMemoryProviderCredentialStore(values: [
            "online": "old-online",
            "removed": "old-removed"
        ])
        let name = "AIProviderStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.set(
            try JSONEncoder().encode([
                AIProviderProfile(
                    id: AIConfigurationStore.defaultProviderID,
                    name: "默认服务",
                    lanes: [
                        lane(id: "online", model: "old-model"),
                        lane(id: "removed", model: "removed-model")
                    ],
                    source: .builtIn
                )
            ]),
            forKey: "DailyReader.ai.providers.v3"
        )
        let current = defaultProfile(lanes: [lane(id: "online", model: "new-model")])
        let store = AIConfigurationStore(
            defaults: defaults,
            credentialStore: credentials,
            builtInProviders: [current]
        )
        defer { defaults.removePersistentDomain(forName: name) }

        try store.installBuiltInProviders([current], apiKeys: ["online": "new-online"])

        XCTAssertNil(try credentials.loadAPIKey(providerID: "removed"))
        XCTAssertEqual(try credentials.loadAPIKey(providerID: "online"), "new-online")
    }

    private func makeStore() throws -> (store: AIConfigurationStore, defaults: UserDefaults) {
        let name = "AIProviderStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let credentials = InMemoryProviderCredentialStore(values: [
            "online": "online-key",
            "sensenova_gou": "gou-key",
            "eric": "eric-key"
        ])
        let store = AIConfigurationStore(
            defaults: defaults,
            credentialStore: credentials,
            builtInProviders: [defaultProfile()]
        )
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return (store, defaults)
    }

    private func defaultProfile(lanes: [AIProviderLaneProfile]? = nil) -> AIProviderProfile {
        AIProviderProfile(
            id: AIConfigurationStore.defaultProviderID,
            name: "默认服务",
            lanes: lanes ?? [
                lane(id: "online", model: "model-a"),
                lane(id: "sensenova_gou", model: "model-b"),
                lane(id: "eric", model: "model-c")
            ],
            source: .builtIn
        )
    }

    private func lane(
        id: String,
        endpoint: String = "https://example.com/v1",
        model: String
    ) -> AIProviderLaneProfile {
        AIProviderLaneProfile(id: id, configuration: configuration(endpoint: endpoint, model: model))
    }

    private func configuration(
        endpoint: String = "https://example.com/v1",
        model: String
    ) -> AIConfiguration {
        AIConfiguration(endpoint: endpoint, model: model, allowsSearchTools: true)
    }
}

private struct LegacyProviderFixture: Encodable {
    let id: String
    var name: String
    var configuration: AIConfiguration
    var source: AIProviderSource
    var isEnabled: Bool
}

private final class InMemoryProviderCredentialStore: AICredentialStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String]

    init(values: [String: String] = [:]) {
        self.values = values
    }

    func loadAPIKey() throws -> String? {
        try loadAPIKey(providerID: AIConfigurationStore.userProviderID)
    }

    func saveAPIKey(_ value: String) throws {
        try saveAPIKey(value, providerID: AIConfigurationStore.userProviderID)
    }

    func deleteAPIKey() throws {
        try deleteAPIKey(providerID: AIConfigurationStore.userProviderID)
    }

    func loadAPIKey(providerID: String) throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        return values[providerID]
    }

    func saveAPIKey(_ value: String, providerID: String) throws {
        lock.lock()
        values[providerID] = value
        lock.unlock()
    }

    func deleteAPIKey(providerID: String) throws {
        lock.lock()
        values.removeValue(forKey: providerID)
        lock.unlock()
    }
}
