import XCTest
@testable import DailyReader

final class OAuthConfigurationTests: XCTestCase {
    func testMissingValuesFailClosed() {
        let result = BundleAuthenticationConfigurationLoader(values: [:]).load()
        XCTAssertEqual(try? result.get(), nil)
        XCTAssertEqual(result.failure, .missingRequiredValues)
    }

    func testHTTPAuthorizationEndpointIsRejected() {
        let configuration = makeTestConfiguration(
            authorizationEndpoint: URL(string: "http://auth.invalid.example/authorize")!
        )
        XCTAssertThrowsError(try configuration.validate()) { error in
            XCTAssertEqual(error as? UnconfiguredReason, .invalidEndpoint)
        }
    }

    func testEndpointMustMatchExactAllowedOrigin() {
        let endpoint = URL(string: "https://evil.api.invalid.example/exchange")!
        let configuration = OAuthConfiguration(
            clientID: "public-test-client",
            redirectURI: URL(string: "test-reader://oauth/callback")!,
            authorizationEndpoint: URL(string: "https://auth.invalid.example/authorize")!,
            exchangeEndpoint: endpoint,
            profileEndpoint: URL(string: "https://api.invalid.example/profile")!,
            refreshEndpoint: nil,
            revocationEndpoint: nil,
            scopes: ["profile"],
            exchangeRoute: .providerPKCE,
            allowedAuthorizationOrigins: [HTTPSOrigin(url: URL(string: "https://auth.invalid.example")!)!],
            allowedAPIOrigins: [HTTPSOrigin(url: URL(string: "https://api.invalid.example")!)!],
            allowedAvatarOrigins: []
        )
        XCTAssertThrowsError(try configuration.validate()) { error in
            XCTAssertEqual(error as? UnconfiguredReason, .invalidOriginPolicy)
        }
    }
}

private extension Result {
    var failure: Failure? {
        if case let .failure(error) = self { return error }
        return nil
    }
}
