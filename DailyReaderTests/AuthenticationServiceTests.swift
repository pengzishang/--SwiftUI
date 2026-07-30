import XCTest
@testable import DailyReader

final class AuthenticationServiceTests: XCTestCase {
    func testSignInPersistsTokenBeforeReturningProfile() async throws {
        let profile = try AuthUserProfile(subject: "user", displayName: "Reader", avatarURL: nil)
        let token = try OAuthTokenSet(
            accessToken: "synthetic-access",
            refreshToken: nil,
            tokenType: "Bearer",
            expiresAt: nil,
            grantedScopes: ["profile"]
        )
        let store = RecordingAuthSessionStore()
        let api = AuthenticationAPIDouble(token: token, profile: profile, store: store)
        let service = makeService(api: api, store: store)

        let result = try await service.signIn { _ in }

        let savedToken = await store.savedSession?.tokenSet
        let observedPersistedSession = await api.profileObservedPersistedSession
        XCTAssertEqual(result, profile)
        XCTAssertEqual(savedToken, token)
        XCTAssertTrue(observedPersistedSession)
    }

    func testRestoreInvalidSessionDeletesOnlyAuthSession() async throws {
        let token = try OAuthTokenSet(
            accessToken: "expired-access",
            refreshToken: nil,
            tokenType: "Bearer",
            expiresAt: nil,
            grantedScopes: []
        )
        let store = RecordingAuthSessionStore(session: StoredAuthSession(tokenSet: token))
        let profile = try AuthUserProfile(subject: "user", displayName: "Reader", avatarURL: nil)
        let api = AuthenticationAPIDouble(token: token, profile: profile, store: store, fetchError: .invalidSession)
        let service = makeService(api: api, store: store)

        do {
            _ = try await service.restoreSession { _ in }
            XCTFail("Expected invalid session")
        } catch {
            XCTAssertEqual(error as? AuthenticationError, .invalidSession)
        }
        let didDelete = await store.didDelete
        let savedSession = await store.savedSession
        XCTAssertTrue(didDelete)
        XCTAssertNil(savedSession)
    }

    func testSignOutRemainsLocalWhenRemoteRevocationFails() async throws {
        let profile = try AuthUserProfile(subject: "user", displayName: "Reader", avatarURL: nil)
        let token = try OAuthTokenSet(
            accessToken: "synthetic-access",
            refreshToken: nil,
            tokenType: "Bearer",
            expiresAt: nil,
            grantedScopes: []
        )
        let store = RecordingAuthSessionStore(session: StoredAuthSession(tokenSet: token))
        let api = AuthenticationAPIDouble(
            token: token,
            profile: profile,
            store: store,
            revokeError: .serviceFailure
        )
        let service = makeService(api: api, store: store)

        let result = await service.signOut()

        XCTAssertEqual(result, SignOutResult(localSessionRemoved: true, remoteRevocationFailed: true))
        let didDelete = await store.didDelete
        let savedSession = await store.savedSession
        XCTAssertTrue(didDelete)
        XCTAssertNil(savedSession)
    }

    private func makeService(
        api: AuthenticationAPIDouble,
        store: RecordingAuthSessionStore
    ) -> ProductionAuthenticationService {
        ProductionAuthenticationService(
            configuration: makeTestConfiguration(),
            pkceGenerator: FixedPKCEGenerator(),
            requestBuilder: FixedAuthorizationRequestBuilder(),
            webSession: FixedWebAuthenticationSession(),
            callbackValidator: FixedCallbackValidator(),
            api: api,
            sessionStore: store,
            now: { Date(timeIntervalSince1970: 1) }
        )
    }
}

private struct FixedPKCEGenerator: PKCEGenerating {
    func generateState() throws -> String { "expected-state" }
    func generatePair() throws -> PKCEPair { PKCEPair(verifier: "synthetic-verifier", challenge: "synthetic-challenge") }
}

private struct FixedAuthorizationRequestBuilder: AuthorizationRequestBuilding {
    func build(configuration: OAuthConfiguration, transaction: AuthorizationTransaction, challenge: String) throws -> URL {
        configuration.authorizationEndpoint
    }
}

private actor FixedWebAuthenticationSession: WebAuthenticationSession {
    func start(authorizationURL: URL, callbackScheme: String, prefersEphemeral: Bool) async throws -> URL {
        URL(string: "test-reader://oauth/callback?code=synthetic-code&state=expected-state")!
    }

    func cancel() async {}
}

private struct FixedCallbackValidator: OAuthCallbackValidating {
    func validate(
        callbackURL: URL,
        transaction: inout AuthorizationTransaction,
        configuration: OAuthConfiguration,
        now: Date
    ) throws -> ValidatedAuthorizationCode {
        transaction.callbackConsumed = true
        return ValidatedAuthorizationCode(value: "synthetic-code")
    }
}

private actor RecordingAuthSessionStore: AuthSessionStoring {
    private(set) var savedSession: StoredAuthSession?
    private(set) var didDelete = false

    init(session: StoredAuthSession? = nil) {
        savedSession = session
    }

    func load() async throws -> StoredAuthSession? { savedSession }

    func save(_ session: StoredAuthSession) async throws {
        savedSession = session
    }

    func delete() async throws {
        didDelete = true
        savedSession = nil
    }
}

private actor AuthenticationAPIDouble: AuthenticationAPI {
    let token: OAuthTokenSet
    let profile: AuthUserProfile
    let store: RecordingAuthSessionStore
    let fetchError: AuthenticationError?
    let revokeError: AuthenticationError?
    private(set) var profileObservedPersistedSession = false

    init(
        token: OAuthTokenSet,
        profile: AuthUserProfile,
        store: RecordingAuthSessionStore,
        fetchError: AuthenticationError? = nil,
        revokeError: AuthenticationError? = nil
    ) {
        self.token = token
        self.profile = profile
        self.store = store
        self.fetchError = fetchError
        self.revokeError = revokeError
    }

    func exchangeCode(
        _ code: ValidatedAuthorizationCode,
        verifier: String,
        configuration: OAuthConfiguration
    ) async throws -> OAuthTokenSet {
        token
    }

    func fetchProfile(accessToken: String, configuration: OAuthConfiguration) async throws -> AuthUserProfile {
        profileObservedPersistedSession = await store.savedSession != nil
        if let fetchError { throw fetchError }
        return profile
    }

    func refresh(refreshToken: String, configuration: OAuthConfiguration) async throws -> OAuthTokenSet {
        token
    }

    func revokeIfConfigured(tokenSet: OAuthTokenSet, configuration: OAuthConfiguration) async throws {
        if let revokeError { throw revokeError }
    }
}
