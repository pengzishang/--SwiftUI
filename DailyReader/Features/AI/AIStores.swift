import Foundation
import SwiftUI

protocol AICredentialStoring: Sendable {
    func loadAPIKey() throws -> String?
    func saveAPIKey(_ value: String) throws
    func deleteAPIKey() throws
    func loadAPIKey(providerID: String) throws -> String?
    func saveAPIKey(_ value: String, providerID: String) throws
    func deleteAPIKey(providerID: String) throws
}

extension AICredentialStoring {
    func loadAPIKey(providerID: String) throws -> String? {
        providerID == AIConfigurationStore.userProviderID ? try loadAPIKey() : nil
    }

    func saveAPIKey(_ value: String, providerID: String) throws {
        if providerID == AIConfigurationStore.userProviderID { try saveAPIKey(value) }
    }

    func deleteAPIKey(providerID: String) throws {
        if providerID == AIConfigurationStore.userProviderID { try deleteAPIKey() }
    }
}

enum AICredentialStoreError: LocalizedError {
    case encodingFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "无法保存 API Key"
        case .saveFailed: return "API Key 未能写入钥匙串"
        }
    }
}

struct AIKeychainCredentialStore: AICredentialStoring, @unchecked Sendable {
    private let prefix = "DailyReader.ai.provider."
    private let legacyKey = "DailyReader.ai.apiKey"

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
        let account = prefix + providerID
        if let data = KeychainHelper.shared.read(forKey: account) {
            return String(data: data, encoding: .utf8)
        }
        guard providerID == AIConfigurationStore.userProviderID,
              let legacyData = KeychainHelper.shared.read(forKey: legacyKey),
              let value = String(data: legacyData, encoding: .utf8) else { return nil }
        try saveAPIKey(value, providerID: providerID)
        KeychainHelper.shared.delete(forKey: legacyKey)
        return value
    }

    func saveAPIKey(_ value: String, providerID: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw AICredentialStoreError.encodingFailed
        }
        let account = prefix + providerID
        KeychainHelper.shared.save(data, forKey: account)
        guard KeychainHelper.shared.read(forKey: account) == data else {
            throw AICredentialStoreError.saveFailed
        }
    }

    func deleteAPIKey(providerID: String) throws {
        KeychainHelper.shared.delete(forKey: prefix + providerID)
        if providerID == AIConfigurationStore.userProviderID {
            KeychainHelper.shared.delete(forKey: legacyKey)
        }
    }
}

actor AISessionStore {
    private struct Envelope: Codable {
        var schemaVersion: Int
        var sessions: [AIChatSession]
    }

    private let fileManager: FileManager
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var latestRevision: UInt64 = 0

    init(fileManager: FileManager = .default, rootURL: URL? = nil) {
        self.fileManager = fileManager
        let baseURL = rootURL
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.fileURL = baseURL
            .appendingPathComponent("DailyReader", isDirectory: true)
            .appendingPathComponent("AI", isDirectory: true)
            .appendingPathComponent("sessions.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    func load() throws -> [AIChatSession] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let envelope: Envelope
        do {
            envelope = try decoder.decode(Envelope.self, from: data)
        } catch {
            let legacyDecoder = JSONDecoder()
            legacyDecoder.dateDecodingStrategy = .iso8601
            envelope = try legacyDecoder.decode(Envelope.self, from: data)
        }
        return envelope.sessions.map { session in
            var recovered = session
            recovered.messages = session.messages.map { message in
                guard message.state == .streaming else { return message }
                var interrupted = message
                interrupted.state = .interrupted
                return interrupted
            }
            return recovered
        }
    }

    func save(_ sessions: [AIChatSession]) throws {
        let revision = latestRevision == UInt64.max ? UInt64.max : latestRevision + 1
        try save(sessions, revision: revision)
    }

    func save(_ sessions: [AIChatSession], revision: UInt64) throws {
        guard revision > latestRevision else { return }
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try encoder.encode(Envelope(schemaVersion: 1, sessions: sessions))
        try data.write(to: fileURL, options: [.atomic])
        latestRevision = revision
    }
}

@MainActor
final class AIConfigurationStore: ObservableObject {
    static let userProviderID = "user.custom"
    static let defaultProviderID = "builtin.default"

    private struct LegacyProviderProfile: Codable {
        let id: String
        var name: String
        var configuration: AIConfiguration
        var source: AIProviderSource
        var isEnabled: Bool
    }

    @Published private(set) var providers: [AIProviderProfile]

    private let defaults: UserDefaults
    private let credentialStore: AICredentialStoring
    private let providersKey = "DailyReader.ai.providers.v3"
    private let legacyProvidersKey = "DailyReader.ai.providers.v2"
    private let legacyConfigurationKey = "DailyReader.ai.configuration"
    private var obsoleteBuiltInLaneIDs = Set<String>()

    init(
        defaults: UserDefaults = .standard,
        credentialStore: AICredentialStoring = AIKeychainCredentialStore(),
        builtInProviders: [AIProviderProfile] = []
    ) {
        self.defaults = defaults
        self.credentialStore = credentialStore

        if let data = defaults.data(forKey: providersKey),
           let decoded = try? JSONDecoder().decode([AIProviderProfile].self, from: data) {
            self.obsoleteBuiltInLaneIDs = Self.obsoleteBuiltInLaneIDs(
                in: decoded,
                comparedWith: builtInProviders
            )
            self.providers = Self.merging(decoded, with: builtInProviders)
            persist()
        } else if let data = defaults.data(forKey: legacyProvidersKey),
                  let legacy = try? JSONDecoder().decode([LegacyProviderProfile].self, from: data) {
            self.obsoleteBuiltInLaneIDs = Self.obsoleteLegacyBuiltInLaneIDs(
                in: legacy,
                comparedWith: builtInProviders
            )
            self.providers = Self.migrating(legacy, with: builtInProviders)
            persist()
        } else {
            var initial: [AIProviderProfile] = []
            if let data = defaults.data(forKey: legacyConfigurationKey),
               let configuration = try? JSONDecoder().decode(AIConfiguration.self, from: data),
               configuration.isComplete {
                initial.append(Self.userProfile(configuration: configuration))
            }
            initial.append(contentsOf: builtInProviders)
            self.providers = initial
            persist()
        }
    }

    var configuration: AIConfiguration {
        userProvider?.configuration ?? .empty
    }

    var userProvider: AIProviderProfile? {
        providers.first(where: { $0.id == Self.userProviderID })
    }

    var enabledProviderCount: Int {
        Set(runtimeProviders().map(\.providerID)).count
    }

    var enabledProviderSummary: String {
        let count = enabledProviderCount
        return count == 0 ? "未启用" : "\(count) 个服务"
    }

    var hasAPIKey: Bool {
        hasAPIKey(providerID: Self.userProviderID)
    }

    var isReady: Bool {
        !runtimeProviders().isEmpty
    }

    func hasAPIKey(providerID: String) -> Bool {
        ((try? credentialStore.loadAPIKey(providerID: providerID)) ?? nil)?.isEmpty == false
    }

    func apiKey() throws -> String {
        try apiKey(providerID: Self.userProviderID)
    }

    func apiKey(providerID: String) throws -> String {
        guard let value = try credentialStore.loadAPIKey(providerID: providerID), !value.isEmpty else {
            throw AIChatError.missingAPIKey
        }
        return value
    }

    func runtimeProviders(
        providerID: String? = nil,
        includeDisabled: Bool = false
    ) -> [AIProviderRuntimeConfiguration] {
        var seenCredentials = Set<String>()
        return providers.flatMap { profile -> [AIProviderRuntimeConfiguration] in
            guard (profile.isEnabled || includeDisabled),
                  providerID == nil || profile.id == providerID else { return [] }
            return profile.lanes.compactMap { lane in
                guard let endpoint = lane.configuration.normalizedEndpointURL,
                      let key = try? apiKey(providerID: lane.id) else { return nil }
                let identity = endpoint.absoluteString.lowercased()
                    + "\u{1f}" + lane.configuration.model.trimmingCharacters(in: .whitespacesAndNewlines)
                    + "\u{1f}" + key
                guard seenCredentials.insert(identity).inserted else { return nil }
                return AIProviderRuntimeConfiguration(
                    providerID: profile.id,
                    providerName: profile.name,
                    laneID: lane.id,
                    configuration: lane.configuration,
                    apiKey: key
                )
            }
        }
    }

    func save(configuration: AIConfiguration, apiKey: String?) throws {
        try saveUserProvider(configuration: configuration, apiKey: apiKey)
    }

    func saveUserProvider(configuration: AIConfiguration, apiKey: String?) throws {
        let trimmedKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedKey, !trimmedKey.isEmpty {
            try credentialStore.saveAPIKey(trimmedKey, providerID: Self.userProviderID)
        }
        if let index = providers.firstIndex(where: { $0.id == Self.userProviderID }) {
            providers[index].configuration = configuration
            providers[index].isEnabled = true
        } else {
            providers.insert(Self.userProfile(configuration: configuration), at: 0)
        }
        persist()
    }

    func installBuiltInProviders(_ profiles: [AIProviderProfile], apiKeys: [String: String]) throws {
        let installedLaneIDs = Set(profiles.flatMap { $0.lanes.map(\.id) })
        let currentLaneIDs = Set(
            providers.lazy
                .filter(\.isBuiltIn)
                .flatMap { $0.lanes.map(\.id) }
        )
        let removedLaneIDs = obsoleteBuiltInLaneIDs.union(currentLaneIDs.subtracting(installedLaneIDs))
        for laneID in removedLaneIDs {
            try credentialStore.deleteAPIKey(providerID: laneID)
        }
        obsoleteBuiltInLaneIDs.removeAll()
        for (laneID, apiKey) in apiKeys where installedLaneIDs.contains(laneID) && !apiKey.isEmpty {
            try credentialStore.saveAPIKey(apiKey, providerID: laneID)
        }
        providers = Self.merging(providers, with: profiles)
        persist()
    }

    func setEnabled(_ enabled: Bool, providerID: String) {
        guard let index = providers.firstIndex(where: { $0.id == providerID }) else { return }
        providers[index].isEnabled = enabled
        persist()
    }

    func moveProviders(fromOffsets: IndexSet, toOffset: Int) {
        providers.move(fromOffsets: fromOffsets, toOffset: toOffset)
        persist()
    }

    func clearAPIKey() throws {
        try credentialStore.deleteAPIKey(providerID: Self.userProviderID)
        objectWillChange.send()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(providers) else { return }
        defaults.set(data, forKey: providersKey)
    }

    private static func userProfile(configuration: AIConfiguration) -> AIProviderProfile {
        AIProviderProfile(
            id: userProviderID,
            name: "我的服务",
            configuration: configuration,
            source: .user
        )
    }

    private static func merging(
        _ saved: [AIProviderProfile],
        with builtIns: [AIProviderProfile]
    ) -> [AIProviderProfile] {
        var result = saved
        for builtIn in builtIns {
            if let index = result.firstIndex(where: { $0.id == builtIn.id }) {
                let enabled = result[index].isEnabled
                result[index] = builtIn
                result[index].isEnabled = enabled
            } else {
                result.append(builtIn)
            }
        }
        let validBuiltInIDs = Set(builtIns.map(\.id))
        return result.filter { $0.source == .user || validBuiltInIDs.contains($0.id) }
    }

    private static func migrating(
        _ legacy: [LegacyProviderProfile],
        with builtIns: [AIProviderProfile]
    ) -> [AIProviderProfile] {
        let builtInByLaneID = Dictionary(
            uniqueKeysWithValues: builtIns.flatMap { profile in
                profile.lanes.map { ($0.id, profile) }
            }
        )
        let enabledByProviderID = Dictionary(
            uniqueKeysWithValues: builtIns.map { profile in
                let legacyMatches = legacy.filter { item in
                    item.source == .builtIn && profile.lanes.contains(where: { $0.id == item.id })
                }
                return (profile.id, legacyMatches.isEmpty ? profile.isEnabled : legacyMatches.contains(where: \.isEnabled))
            }
        )
        var insertedBuiltInIDs = Set<String>()
        var result: [AIProviderProfile] = []

        for item in legacy {
            if item.source == .user || item.id == userProviderID {
                var user = userProfile(configuration: item.configuration)
                user.isEnabled = item.isEnabled
                result.append(user)
                continue
            }
            guard var builtIn = builtInByLaneID[item.id],
                  insertedBuiltInIDs.insert(builtIn.id).inserted else { continue }
            builtIn.isEnabled = enabledByProviderID[builtIn.id] ?? builtIn.isEnabled
            result.append(builtIn)
        }

        for var builtIn in builtIns where insertedBuiltInIDs.insert(builtIn.id).inserted {
            builtIn.isEnabled = enabledByProviderID[builtIn.id] ?? builtIn.isEnabled
            result.append(builtIn)
        }
        return result
    }

    private static func obsoleteBuiltInLaneIDs(
        in saved: [AIProviderProfile],
        comparedWith builtIns: [AIProviderProfile]
    ) -> Set<String> {
        let validLaneIDs = Set(builtIns.flatMap { $0.lanes.map(\.id) })
        let savedLaneIDs = Set(
            saved.lazy
                .filter(\.isBuiltIn)
                .flatMap { $0.lanes.map(\.id) }
        )
        return savedLaneIDs.subtracting(validLaneIDs)
    }

    private static func obsoleteLegacyBuiltInLaneIDs(
        in legacy: [LegacyProviderProfile],
        comparedWith builtIns: [AIProviderProfile]
    ) -> Set<String> {
        let validLaneIDs = Set(builtIns.flatMap { $0.lanes.map(\.id) })
        let legacyLaneIDs = Set(legacy.lazy.filter { $0.source == .builtIn }.map(\.id))
        return legacyLaneIDs.subtracting(validLaneIDs)
    }
}
