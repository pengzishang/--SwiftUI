import XCTest
@testable import DailyReader

final class OAuthHTTPClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testProfileBearerIsRequestLocalAndSentToExactOrigin() async throws {
        let configuration = makeTestConfiguration()
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: sessionConfiguration)
        let contract = OAuthContractDouble()
        let client = OAuthHTTPClient(contract: contract, session: session)

        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url, configuration.profileEndpoint)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer synthetic-access")
            return .init(statusCode: 200, data: Data("{}".utf8))
        }

        let profile = try await client.fetchProfile(accessToken: "synthetic-access", configuration: configuration)
        XCTAssertEqual(profile.displayName, "Test Reader")
    }

    func testExchangeContractCannotRetargetAuthorizationMaterial() async {
        let configuration = makeTestConfiguration()
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: sessionConfiguration)
        let client = OAuthHTTPClient(contract: RetargetingOAuthContractDouble(), session: session)
        MockURLProtocol.handler = { _ in
            XCTFail("Retargeted request must fail before network")
            return .init(statusCode: 200, data: Data())
        }

        do {
            _ = try await client.exchangeCode(
                ValidatedAuthorizationCode(value: "synthetic-code"),
                verifier: "synthetic-verifier",
                configuration: configuration
            )
            XCTFail("Expected fail-closed request target rejection")
        } catch {
            XCTAssertEqual(error as? AuthenticationError, .configurationUnavailable)
        }
    }

    func testProfileWrongOriginFailsBeforeNetwork() async {
        var configuration = makeTestConfiguration()
        configuration = OAuthConfiguration(
            clientID: configuration.clientID,
            redirectURI: configuration.redirectURI,
            authorizationEndpoint: configuration.authorizationEndpoint,
            exchangeEndpoint: configuration.exchangeEndpoint,
            profileEndpoint: URL(string: "https://other.invalid.example/profile")!,
            refreshEndpoint: nil,
            revocationEndpoint: nil,
            scopes: configuration.scopes,
            exchangeRoute: configuration.exchangeRoute,
            allowedAuthorizationOrigins: configuration.allowedAuthorizationOrigins,
            allowedAPIOrigins: configuration.allowedAPIOrigins,
            allowedAvatarOrigins: []
        )
        let client = OAuthHTTPClient(contract: OAuthContractDouble())
        do {
            _ = try await client.fetchProfile(accessToken: "synthetic-access", configuration: configuration)
            XCTFail("Expected fail-closed origin rejection")
        } catch {
            XCTAssertEqual(error as? AuthenticationError, .configurationUnavailable)
        }
    }
}

private struct RetargetingOAuthContractDouble: OAuthTransportContract {
    func exchangeRequest(endpoint: URL, code: ValidatedAuthorizationCode, verifier: String, configuration: OAuthConfiguration) throws -> URLRequest {
        URLRequest(url: URL(string: "https://other.invalid.example/exchange")!)
    }

    func refreshRequest(endpoint: URL, refreshToken: String) throws -> URLRequest { URLRequest(url: endpoint) }
    func revocationRequest(endpoint: URL, accessToken: String) throws -> URLRequest { URLRequest(url: endpoint) }

    func decodeToken(data: Data, response: HTTPURLResponse, now: Date) throws -> OAuthTokenSet {
        try OAuthTokenSet(accessToken: "synthetic-access", refreshToken: nil, tokenType: "Bearer", expiresAt: nil, grantedScopes: [])
    }

    func decodeProfile(data: Data, response: HTTPURLResponse, configuration: OAuthConfiguration) throws -> AuthUserProfile {
        try AuthUserProfile(subject: "test-user", displayName: "Test Reader", avatarURL: nil)
    }
}

private struct OAuthContractDouble: OAuthTransportContract {
    func exchangeRequest(endpoint: URL, code: ValidatedAuthorizationCode, verifier: String, configuration: OAuthConfiguration) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        return request
    }

    func refreshRequest(endpoint: URL, refreshToken: String) throws -> URLRequest { URLRequest(url: endpoint) }
    func revocationRequest(endpoint: URL, accessToken: String) throws -> URLRequest { URLRequest(url: endpoint) }

    func decodeToken(data: Data, response: HTTPURLResponse, now: Date) throws -> OAuthTokenSet {
        try OAuthTokenSet(accessToken: "synthetic-access", refreshToken: nil, tokenType: "Bearer", expiresAt: nil, grantedScopes: [])
    }

    func decodeProfile(data: Data, response: HTTPURLResponse, configuration: OAuthConfiguration) throws -> AuthUserProfile {
        try AuthUserProfile(subject: "test-user", displayName: "Test Reader", avatarURL: nil)
    }
}
