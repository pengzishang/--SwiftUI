import Foundation

protocol OAuthContractAdapting: Sendable {
    func authorizationQueryItems(
        configuration: OAuthConfiguration,
        transaction: AuthorizationTransaction,
        challenge: String
    ) -> [URLQueryItem]
}

struct StandardPKCEContractAdapter: OAuthContractAdapting {
    func authorizationQueryItems(
        configuration: OAuthConfiguration,
        transaction: AuthorizationTransaction,
        challenge: String
    ) -> [URLQueryItem] {
        [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI.absoluteString),
            URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: transaction.state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
    }
}

protocol AuthorizationRequestBuilding: Sendable {
    func build(
        configuration: OAuthConfiguration,
        transaction: AuthorizationTransaction,
        challenge: String
    ) throws -> URL
}

struct AuthorizationRequestBuilder: AuthorizationRequestBuilding {
    let adapter: any OAuthContractAdapting

    init(adapter: any OAuthContractAdapting = StandardPKCEContractAdapter()) {
        self.adapter = adapter
    }

    func build(
        configuration: OAuthConfiguration,
        transaction: AuthorizationTransaction,
        challenge: String
    ) throws -> URL {
        try configuration.validate()
        guard var components = URLComponents(url: configuration.authorizationEndpoint, resolvingAgainstBaseURL: false),
              components.queryItems == nil else {
            throw AuthenticationError.configurationUnavailable
        }
        components.queryItems = adapter.authorizationQueryItems(
            configuration: configuration,
            transaction: transaction,
            challenge: challenge
        )
        guard let url = components.url else { throw AuthenticationError.configurationUnavailable }
        return url
    }
}
