import Foundation

protocol OAuthTransportContract: Sendable {
    func exchangeRequest(
        endpoint: URL,
        code: ValidatedAuthorizationCode,
        verifier: String,
        configuration: OAuthConfiguration
    ) throws -> URLRequest
    func refreshRequest(endpoint: URL, refreshToken: String) throws -> URLRequest
    func revocationRequest(endpoint: URL, accessToken: String) throws -> URLRequest
    func decodeToken(data: Data, response: HTTPURLResponse, now: Date) throws -> OAuthTokenSet
    func decodeProfile(data: Data, response: HTTPURLResponse, configuration: OAuthConfiguration) throws -> AuthUserProfile
}

protocol AuthenticationAPI: Sendable {
    func exchangeCode(_ code: ValidatedAuthorizationCode, verifier: String, configuration: OAuthConfiguration) async throws -> OAuthTokenSet
    func fetchProfile(accessToken: String, configuration: OAuthConfiguration) async throws -> AuthUserProfile
    func refresh(refreshToken: String, configuration: OAuthConfiguration) async throws -> OAuthTokenSet
    func revokeIfConfigured(tokenSet: OAuthTokenSet, configuration: OAuthConfiguration) async throws
}

final class AuthenticationSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

final class OAuthHTTPClient: AuthenticationAPI, @unchecked Sendable {
    private let session: URLSession
    private let contract: any OAuthTransportContract
    private let now: @Sendable () -> Date

    init(
        contract: any OAuthTransportContract,
        session: URLSession? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.contract = contract
        self.now = now
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.httpCookieStorage = nil
            configuration.urlCredentialStorage = nil
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 30
            self.session = URLSession(configuration: configuration, delegate: AuthenticationSessionDelegate(), delegateQueue: nil)
        }
    }

    func exchangeCode(
        _ code: ValidatedAuthorizationCode,
        verifier: String,
        configuration: OAuthConfiguration
    ) async throws -> OAuthTokenSet {
        try validate(configuration.exchangeEndpoint, allowed: configuration.allowedAPIOrigins)
        let request = try contract.exchangeRequest(
            endpoint: configuration.exchangeEndpoint,
            code: code,
            verifier: verifier,
            configuration: configuration
        )
        try validate(request, targets: configuration.exchangeEndpoint)
        let (data, response) = try await perform(request)
        return try contract.decodeToken(data: data, response: response, now: now())
    }

    func fetchProfile(accessToken: String, configuration: OAuthConfiguration) async throws -> AuthUserProfile {
        try validate(configuration.profileEndpoint, allowed: configuration.allowedAPIOrigins)
        var request = URLRequest(url: configuration.profileEndpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await perform(request)
        guard response.statusCode != 401, response.statusCode != 403 else {
            throw AuthenticationError.invalidSession
        }
        return try contract.decodeProfile(data: data, response: response, configuration: configuration)
    }

    func refresh(refreshToken: String, configuration: OAuthConfiguration) async throws -> OAuthTokenSet {
        guard let endpoint = configuration.refreshEndpoint else { throw AuthenticationError.refreshFailure }
        try validate(endpoint, allowed: configuration.allowedAPIOrigins)
        let request = try contract.refreshRequest(endpoint: endpoint, refreshToken: refreshToken)
        try validate(request, targets: endpoint)
        let (data, response) = try await perform(request)
        return try contract.decodeToken(data: data, response: response, now: now())
    }

    func revokeIfConfigured(tokenSet: OAuthTokenSet, configuration: OAuthConfiguration) async throws {
        guard let endpoint = configuration.revocationEndpoint else { return }
        try validate(endpoint, allowed: configuration.allowedAPIOrigins)
        let request = try contract.revocationRequest(endpoint: endpoint, accessToken: tokenSet.accessToken)
        try validate(request, targets: endpoint)
        _ = try await perform(request)
    }

    private func validate(_ endpoint: URL, allowed: Set<HTTPSOrigin>) throws {
        guard let origin = HTTPSOrigin(url: endpoint), allowed.contains(origin) else {
            throw AuthenticationError.configurationUnavailable
        }
    }

    private func validate(_ request: URLRequest, targets endpoint: URL) throws {
        guard request.url == endpoint else {
            throw AuthenticationError.configurationUnavailable
        }
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw AuthenticationError.invalidResponse }
            switch response.statusCode {
            case 200..<300: return (data, response)
            case 401, 403: throw AuthenticationError.invalidSession
            case 429, 500...599: throw AuthenticationError.serviceFailure
            default: throw AuthenticationError.invalidResponse
            }
        } catch let error as AuthenticationError {
            throw error
        } catch {
            throw AuthenticationError.transportFailure
        }
    }
}
