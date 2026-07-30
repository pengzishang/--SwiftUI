import Foundation

protocol AuthProfileStoring: Sendable {
    func load() async -> AuthUserProfile?
    func save(_ profile: AuthUserProfile?) async
}

actor InMemoryAuthProfileStore: AuthProfileStoring {
    private var profile: AuthUserProfile?

    init(profile: AuthUserProfile? = nil) { self.profile = profile }
    func load() async -> AuthUserProfile? { profile }
    func save(_ profile: AuthUserProfile?) async { self.profile = profile }
}

protocol AuthenticationServicing: Sendable {
    var availability: AuthenticationAvailability { get }
    func signIn(progress: @escaping @MainActor @Sendable (AuthenticationProgress) -> Void) async throws -> AuthUserProfile
    func restoreSession(progress: @escaping @MainActor @Sendable (AuthenticationProgress) -> Void) async throws -> AuthUserProfile?
    func retryProfile() async throws -> AuthUserProfile
    func signOut() async -> SignOutResult
    func cancel() async
}

actor UnavailableAuthenticationService: AuthenticationServicing {
    nonisolated let availability: AuthenticationAvailability

    init(reason: UnconfiguredReason) {
        availability = .unconfigured(reason)
    }

    func signIn(progress: @escaping @MainActor @Sendable (AuthenticationProgress) -> Void) async throws -> AuthUserProfile {
        throw AuthenticationError.configurationUnavailable
    }

    func restoreSession(progress: @escaping @MainActor @Sendable (AuthenticationProgress) -> Void) async throws -> AuthUserProfile? { nil }
    func retryProfile() async throws -> AuthUserProfile { throw AuthenticationError.configurationUnavailable }
    func signOut() async -> SignOutResult { SignOutResult(localSessionRemoved: true, remoteRevocationFailed: false) }
    func cancel() async {}
}

actor ProductionAuthenticationService: AuthenticationServicing {
    nonisolated let availability: AuthenticationAvailability = .configured

    private let configuration: OAuthConfiguration
    private let pkceGenerator: any PKCEGenerating
    private let requestBuilder: any AuthorizationRequestBuilding
    private let webSession: any WebAuthenticationSession
    private let callbackValidator: any OAuthCallbackValidating
    private let api: any AuthenticationAPI
    private let sessionStore: any AuthSessionStoring
    private let profileStore: any AuthProfileStoring
    private let now: @Sendable () -> Date
    private var activeTransaction: AuthorizationTransaction?
    private var currentTokenSet: OAuthTokenSet?

    init(
        configuration: OAuthConfiguration,
        pkceGenerator: any PKCEGenerating,
        requestBuilder: any AuthorizationRequestBuilding,
        webSession: any WebAuthenticationSession,
        callbackValidator: any OAuthCallbackValidating,
        api: any AuthenticationAPI,
        sessionStore: any AuthSessionStoring,
        profileStore: any AuthProfileStoring = InMemoryAuthProfileStore(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.configuration = configuration
        self.pkceGenerator = pkceGenerator
        self.requestBuilder = requestBuilder
        self.webSession = webSession
        self.callbackValidator = callbackValidator
        self.api = api
        self.sessionStore = sessionStore
        self.profileStore = profileStore
        self.now = now
    }

    func signIn(progress: @escaping @MainActor @Sendable (AuthenticationProgress) -> Void) async throws -> AuthUserProfile {
        guard activeTransaction == nil else { throw AuthenticationError.operationAlreadyInProgress }
        await progress(.preparingAuthorization)
        let pair = try pkceGenerator.generatePair()
        let transaction = AuthorizationTransaction(
            id: UUID(), state: try pkceGenerator.generateState(), verifier: pair.verifier,
            createdAt: now(), callbackConsumed: false
        )
        activeTransaction = transaction
        defer { activeTransaction = nil }

        let authorizationURL = try requestBuilder.build(
            configuration: configuration,
            transaction: transaction,
            challenge: pair.challenge
        )
        guard let callbackScheme = configuration.redirectURI.scheme else {
            throw AuthenticationError.configurationUnavailable
        }
        await progress(.authorizing)
        let callbackURL = try await webSession.start(
            authorizationURL: authorizationURL,
            callbackScheme: callbackScheme,
            prefersEphemeral: true
        )
        await progress(.processingCallback)
        guard var activeTransaction else { throw AuthenticationError.invalidCallback }
        let code = try callbackValidator.validate(
            callbackURL: callbackURL,
            transaction: &activeTransaction,
            configuration: configuration,
            now: now()
        )
        self.activeTransaction = activeTransaction
        let tokenSet = try await api.exchangeCode(code, verifier: activeTransaction.verifier, configuration: configuration)
        do {
            try await sessionStore.save(StoredAuthSession(tokenSet: tokenSet))
        } catch {
            throw AuthenticationError.secureStorageFailure
        }
        currentTokenSet = tokenSet
        await progress(.loadingProfile)
        do {
            let profile = try await fetchProfileWithSingleRefresh(tokenSet: tokenSet)
            await profileStore.save(profile)
            return profile
        } catch let error as AuthenticationError {
            throw error == .invalidSession ? AuthenticationError.invalidSession : AuthenticationError.profileFailure
        } catch {
            throw AuthenticationError.profileFailure
        }
    }

    func restoreSession(progress: @escaping @MainActor @Sendable (AuthenticationProgress) -> Void) async throws -> AuthUserProfile? {
        await progress(.restoring)
        let stored: StoredAuthSession?
        do {
            stored = try await sessionStore.load()
        } catch {
            throw AuthenticationError.secureStorageFailure
        }
        guard let stored else { return nil }
        currentTokenSet = stored.tokenSet
        do {
            let profile = try await fetchProfileWithSingleRefresh(tokenSet: stored.tokenSet)
            await profileStore.save(profile)
            return profile
        } catch AuthenticationError.invalidSession {
            try? await sessionStore.delete()
            currentTokenSet = nil
            await profileStore.save(nil)
            throw AuthenticationError.invalidSession
        }
    }

    func retryProfile() async throws -> AuthUserProfile {
        let tokenSet: OAuthTokenSet
        if let currentTokenSet {
            tokenSet = currentTokenSet
        } else if let stored = try? await sessionStore.load() {
            tokenSet = stored.tokenSet
            currentTokenSet = tokenSet
        } else {
            throw AuthenticationError.invalidSession
        }
        let profile = try await fetchProfileWithSingleRefresh(tokenSet: tokenSet)
        await profileStore.save(profile)
        return profile
    }

    func signOut() async -> SignOutResult {
        await webSession.cancel()
        activeTransaction = nil
        let tokenSet: OAuthTokenSet?
        if let currentTokenSet {
            tokenSet = currentTokenSet
        } else {
            tokenSet = (try? await sessionStore.load())?.tokenSet
        }
        do {
            try await sessionStore.delete()
        } catch {
            return SignOutResult(localSessionRemoved: false, remoteRevocationFailed: false)
        }
        currentTokenSet = nil
        await profileStore.save(nil)
        guard let tokenSet else {
            return SignOutResult(localSessionRemoved: true, remoteRevocationFailed: false)
        }
        do {
            try await api.revokeIfConfigured(tokenSet: tokenSet, configuration: configuration)
            return SignOutResult(localSessionRemoved: true, remoteRevocationFailed: false)
        } catch {
            return SignOutResult(localSessionRemoved: true, remoteRevocationFailed: true)
        }
    }

    func cancel() async {
        activeTransaction = nil
        await webSession.cancel()
    }

    private func fetchProfileWithSingleRefresh(tokenSet: OAuthTokenSet) async throws -> AuthUserProfile {
        if let expiresAt = tokenSet.expiresAt, expiresAt <= now() {
            return try await refreshAndFetch(tokenSet: tokenSet)
        }
        do {
            return try await api.fetchProfile(accessToken: tokenSet.accessToken, configuration: configuration)
        } catch AuthenticationError.invalidSession {
            return try await refreshAndFetch(tokenSet: tokenSet)
        }
    }

    private func refreshAndFetch(tokenSet: OAuthTokenSet) async throws -> AuthUserProfile {
        guard configuration.refreshEndpoint != nil, let refreshToken = tokenSet.refreshToken else {
            throw AuthenticationError.invalidSession
        }
        let refreshed: OAuthTokenSet
        do {
            refreshed = try await api.refresh(refreshToken: refreshToken, configuration: configuration)
            try await sessionStore.save(StoredAuthSession(tokenSet: refreshed))
        } catch {
            throw AuthenticationError.refreshFailure
        }
        currentTokenSet = refreshed
        return try await api.fetchProfile(accessToken: refreshed.accessToken, configuration: configuration)
    }
}
