import XCTest
@testable import DailyReader

final class AIBuiltInProviderLoaderTests: XCTestCase {
    func testLoadsOneLogicalProviderWithThreeLanes() throws {
        let payloads = [
            AIBuiltInProviderLoader.Payload(
                id: AIConfigurationStore.defaultProviderID,
                name: "默认服务",
                lanes: [
                    lane(id: "online", model: "model-a", apiKey: "key-a"),
                    lane(id: "sensenova_gou", model: "model-b", apiKey: "key-b"),
                    lane(id: "eric", model: "model-c", apiKey: "key-c", allowsSearchTools: false)
                ]
            )
        ]

        let loaded = AIBuiltInProviderLoader(encodedPayload: try base64URL(payloads)).load()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].profile.id, AIConfigurationStore.defaultProviderID)
        XCTAssertEqual(loaded[0].profile.name, "默认服务")
        XCTAssertEqual(loaded[0].profile.lanes.map(\.id), ["online", "sensenova_gou", "eric"])
        XCTAssertEqual(loaded[0].apiKeys, [
            "online": "key-a",
            "sensenova_gou": "key-b",
            "eric": "key-c"
        ])
        XCTAssertEqual(loaded[0].profile.lanes.last?.configuration.allowsSearchTools, false)
        XCTAssertEqual(loaded[0].profile.source, .builtIn)
    }

    func testDropsInvalidDuplicateProviderAndLaneEntries() throws {
        let payloads = [
            AIBuiltInProviderLoader.Payload(
                id: "first",
                name: "First",
                lanes: [
                    lane(id: "shared", model: "model", apiKey: "key-a"),
                    lane(id: "shared", model: "duplicate", apiKey: "key-b"),
                    lane(id: "http", endpoint: "http://example.com/v1", model: "model", apiKey: "key-c")
                ]
            ),
            AIBuiltInProviderLoader.Payload(
                id: "first",
                name: "Duplicate Provider",
                lanes: [lane(id: "other", model: "model", apiKey: "key-d")]
            ),
            AIBuiltInProviderLoader.Payload(
                id: "second",
                name: "Second",
                lanes: [
                    lane(id: "shared", model: "duplicate-across-groups", apiKey: "key-e"),
                    lane(id: "unique", model: "model", apiKey: "key-f")
                ]
            )
        ]

        let loaded = AIBuiltInProviderLoader(encodedPayload: try base64URL(payloads)).load()

        XCTAssertEqual(loaded.map(\.profile.name), ["First", "Second"])
        XCTAssertEqual(loaded[0].profile.lanes.map(\.id), ["shared"])
        XCTAssertEqual(loaded[1].profile.lanes.map(\.id), ["unique"])
    }

    func testInvalidEmptyGroupDoesNotReserveItsLaneID() throws {
        let payloads = [
            AIBuiltInProviderLoader.Payload(
                id: "invalid",
                name: "Invalid",
                lanes: [lane(id: "reusable", model: "", apiKey: "key-a")]
            ),
            AIBuiltInProviderLoader.Payload(
                id: "valid",
                name: "Valid",
                lanes: [lane(id: "reusable", model: "model", apiKey: "key-b")]
            )
        ]

        let loaded = AIBuiltInProviderLoader(encodedPayload: try base64URL(payloads)).load()

        XCTAssertEqual(loaded.map(\.profile.id), ["valid"])
        XCTAssertEqual(loaded.first?.profile.lanes.map(\.id), ["reusable"])
    }

    func testReturnsEmptyForUnexpandedBuildVariable() {
        XCTAssertTrue(AIBuiltInProviderLoader(encodedPayload: "$(AI_BUILTIN_PROVIDERS_B64URL)").load().isEmpty)
    }

    func testReturnsEmptyForMalformedPayload() {
        XCTAssertTrue(AIBuiltInProviderLoader(encodedPayload: "not-base64url").load().isEmpty)
    }

    private func lane(
        id: String,
        endpoint: String = "https://example.com/v1",
        model: String,
        apiKey: String,
        allowsSearchTools: Bool = true
    ) -> AIBuiltInProviderLoader.LanePayload {
        AIBuiltInProviderLoader.LanePayload(
            id: id,
            endpoint: endpoint,
            model: model,
            apiKey: apiKey,
            allowsSearchTools: allowsSearchTools
        )
    }

    private func base64URL(_ payloads: [AIBuiltInProviderLoader.Payload]) throws -> String {
        try JSONEncoder().encode(payloads)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
