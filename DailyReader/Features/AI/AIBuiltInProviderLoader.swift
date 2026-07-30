import Foundation

struct AIBuiltInProviderLoader: Sendable {
    struct LanePayload: Codable, Equatable, Sendable {
        var id: String
        var endpoint: String
        var model: String
        var apiKey: String
        var allowsSearchTools: Bool
    }

    struct Payload: Codable, Equatable, Sendable {
        var id: String
        var name: String
        var lanes: [LanePayload]
    }

    struct LoadedProvider: Sendable {
        var profile: AIProviderProfile
        var apiKeys: [String: String]
    }

    private let encodedPayload: String?

    init(bundle: Bundle = .main) {
        self.encodedPayload = bundle.object(forInfoDictionaryKey: "AIBuiltInProviders") as? String
    }

    init(encodedPayload: String?) {
        self.encodedPayload = encodedPayload
    }

    func load() -> [LoadedProvider] {
        guard let encodedPayload,
              !encodedPayload.isEmpty,
              !encodedPayload.contains("$("),
              let data = Self.decodeBase64URL(encodedPayload),
              let payloads = try? JSONDecoder().decode([Payload].self, from: data) else {
            return []
        }

        var seenProviderIDs = Set<String>()
        var seenLaneIDs = Set<String>()
        return payloads.compactMap { payload in
            let providerID = payload.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = payload.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !providerID.isEmpty,
                  !name.isEmpty,
                  !seenProviderIDs.contains(providerID) else { return nil }

            var lanes: [AIProviderLaneProfile] = []
            var apiKeys: [String: String] = [:]
            var candidateLaneIDs = Set<String>()
            for lanePayload in payload.lanes {
                let laneID = lanePayload.id.trimmingCharacters(in: .whitespacesAndNewlines)
                let apiKey = lanePayload.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                let configuration = AIConfiguration(
                    endpoint: lanePayload.endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
                    model: lanePayload.model.trimmingCharacters(in: .whitespacesAndNewlines),
                    allowsSearchTools: lanePayload.allowsSearchTools
                )
                guard !laneID.isEmpty,
                      !apiKey.isEmpty,
                      configuration.isComplete,
                      !seenLaneIDs.contains(laneID),
                      candidateLaneIDs.insert(laneID).inserted else { continue }
                lanes.append(AIProviderLaneProfile(id: laneID, configuration: configuration))
                apiKeys[laneID] = apiKey
            }
            guard !lanes.isEmpty else { return nil }

            seenProviderIDs.insert(providerID)
            seenLaneIDs.formUnion(candidateLaneIDs)
            return LoadedProvider(
                profile: AIProviderProfile(
                    id: providerID,
                    name: name,
                    lanes: lanes,
                    source: .builtIn
                ),
                apiKeys: apiKeys
            )
        }
    }

    private static func decodeBase64URL(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }
}
