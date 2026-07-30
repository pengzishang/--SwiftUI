import Foundation

struct HTTPSOrigin: Hashable, Sendable {
    let host: String
    let port: Int?

    init?(url: URL) {
        guard url.scheme?.lowercased() == "https",
              url.user == nil,
              url.password == nil,
              let rawHost = url.host?.lowercased(),
              !rawHost.isEmpty,
              !Self.isIPLiteral(rawHost) else { return nil }
        host = rawHost
        port = url.port == 443 ? nil : url.port
    }

    private static func isIPLiteral(_ host: String) -> Bool {
        if host.contains(":") { return true }
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 4 && parts.allSatisfy { part in
            guard let value = Int(part) else { return false }
            return (0...255).contains(value)
        }
    }
}

enum ExchangeRoute: String, Equatable, Sendable {
    case providerPKCE
    case httpsBFF
}

struct OAuthConfiguration: Equatable, Sendable {
    let clientID: String
    let redirectURI: URL
    let authorizationEndpoint: URL
    let exchangeEndpoint: URL
    let profileEndpoint: URL
    let refreshEndpoint: URL?
    let revocationEndpoint: URL?
    let scopes: [String]
    let exchangeRoute: ExchangeRoute
    let allowedAuthorizationOrigins: Set<HTTPSOrigin>
    let allowedAPIOrigins: Set<HTTPSOrigin>
    let allowedAvatarOrigins: Set<HTTPSOrigin>

    func validate() throws {
        guard !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !scopes.isEmpty,
              scopes.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw UnconfiguredReason.missingRequiredValues
        }
        guard let redirectScheme = redirectURI.scheme, !redirectScheme.isEmpty,
              redirectURI.user == nil,
              redirectURI.password == nil,
              redirectURI.query == nil,
              redirectURI.fragment == nil else {
            throw UnconfiguredReason.invalidRedirect
        }
        try validate(endpoint: authorizationEndpoint, allowed: allowedAuthorizationOrigins)
        try validate(endpoint: exchangeEndpoint, allowed: allowedAPIOrigins)
        try validate(endpoint: profileEndpoint, allowed: allowedAPIOrigins)
        if let refreshEndpoint { try validate(endpoint: refreshEndpoint, allowed: allowedAPIOrigins) }
        if let revocationEndpoint { try validate(endpoint: revocationEndpoint, allowed: allowedAPIOrigins) }
    }

    private func validate(endpoint: URL, allowed: Set<HTTPSOrigin>) throws {
        guard endpoint.fragment == nil, endpoint.query == nil, let origin = HTTPSOrigin(url: endpoint) else {
            throw UnconfiguredReason.invalidEndpoint
        }
        guard allowed.contains(origin) else {
            throw UnconfiguredReason.invalidOriginPolicy
        }
    }
}

extension UnconfiguredReason: Error {}

protocol AuthenticationConfigurationLoading {
    func load() -> Result<OAuthConfiguration, UnconfiguredReason>
}

struct BundleAuthenticationConfigurationLoader: AuthenticationConfigurationLoading {
    private let values: [String: Any]

    init(bundle: Bundle = .main) {
        values = bundle.infoDictionary ?? [:]
    }

    init(values: [String: Any]) {
        self.values = values
    }

    func load() -> Result<OAuthConfiguration, UnconfiguredReason> {
        let requiredKeys = [
            "ZHIHU_OAUTH_CLIENT_ID", "ZHIHU_OAUTH_REDIRECT_URI",
            "ZHIHU_OAUTH_AUTHORIZATION_ENDPOINT", "ZHIHU_OAUTH_EXCHANGE_ENDPOINT",
            "ZHIHU_OAUTH_PROFILE_ENDPOINT", "ZHIHU_OAUTH_SCOPES",
            "ZHIHU_OAUTH_EXCHANGE_ROUTE"
        ]
        guard requiredKeys.allSatisfy({ string($0) != nil }) else {
            return .failure(.missingRequiredValues)
        }
        guard let clientID = string("ZHIHU_OAUTH_CLIENT_ID"),
              let redirectURI = url("ZHIHU_OAUTH_REDIRECT_URI"),
              let authorizationEndpoint = url("ZHIHU_OAUTH_AUTHORIZATION_ENDPOINT"),
              let exchangeEndpoint = url("ZHIHU_OAUTH_EXCHANGE_ENDPOINT"),
              let profileEndpoint = url("ZHIHU_OAUTH_PROFILE_ENDPOINT"),
              let scopeString = string("ZHIHU_OAUTH_SCOPES"),
              let routeValue = string("ZHIHU_OAUTH_EXCHANGE_ROUTE"),
              let route = ExchangeRoute(rawValue: routeValue) else {
            return .failure(.unsupportedContract)
        }

        let authorizationOrigins = origins("ZHIHU_OAUTH_AUTHORIZATION_ORIGINS")
        let apiOrigins = origins("ZHIHU_OAUTH_API_ORIGINS")
        let avatarOrigins = origins("ZHIHU_OAUTH_AVATAR_ORIGINS")
        let configuration = OAuthConfiguration(
            clientID: clientID,
            redirectURI: redirectURI,
            authorizationEndpoint: authorizationEndpoint,
            exchangeEndpoint: exchangeEndpoint,
            profileEndpoint: profileEndpoint,
            refreshEndpoint: optionalURL("ZHIHU_OAUTH_REFRESH_ENDPOINT"),
            revocationEndpoint: optionalURL("ZHIHU_OAUTH_REVOCATION_ENDPOINT"),
            scopes: scopeString.split(separator: " ").map(String.init),
            exchangeRoute: route,
            allowedAuthorizationOrigins: authorizationOrigins,
            allowedAPIOrigins: apiOrigins,
            allowedAvatarOrigins: avatarOrigins
        )
        do {
            try configuration.validate()
            return .success(configuration)
        } catch let reason as UnconfiguredReason {
            return .failure(reason)
        } catch {
            return .failure(.unsupportedContract)
        }
    }

    private func string(_ key: String) -> String? {
        guard let value = values[key] as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("$(") else { return nil }
        return trimmed
    }

    private func url(_ key: String) -> URL? {
        guard let value = string(key), let url = URL(string: value), url.scheme != nil else { return nil }
        return url
    }

    private func optionalURL(_ key: String) -> URL? {
        guard string(key) != nil else { return nil }
        return url(key)
    }

    private func origins(_ key: String) -> Set<HTTPSOrigin> {
        guard let value = string(key) else { return [] }
        return Set(value.split(separator: " ").compactMap { URL(string: String($0)) }.compactMap(HTTPSOrigin.init(url:)))
    }
}
