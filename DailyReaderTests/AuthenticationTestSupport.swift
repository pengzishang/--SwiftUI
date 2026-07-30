import Foundation
@testable import DailyReader

func makeTestConfiguration(
    redirectURI: URL = URL(string: "test-reader://oauth/callback")!,
    authorizationEndpoint: URL = URL(string: "https://auth.invalid.example/authorize")!,
    exchangeEndpoint: URL = URL(string: "https://api.invalid.example/exchange")!,
    profileEndpoint: URL = URL(string: "https://api.invalid.example/profile")!,
    refreshEndpoint: URL? = nil
) -> OAuthConfiguration {
    OAuthConfiguration(
        clientID: "public-test-client",
        redirectURI: redirectURI,
        authorizationEndpoint: authorizationEndpoint,
        exchangeEndpoint: exchangeEndpoint,
        profileEndpoint: profileEndpoint,
        refreshEndpoint: refreshEndpoint,
        revocationEndpoint: nil,
        scopes: ["profile"],
        exchangeRoute: .providerPKCE,
        allowedAuthorizationOrigins: [HTTPSOrigin(url: authorizationEndpoint)!],
        allowedAPIOrigins: [HTTPSOrigin(url: exchangeEndpoint)!, HTTPSOrigin(url: profileEndpoint)!],
        allowedAvatarOrigins: []
    )
}

struct FixedRandomGenerator: SecureRandomGenerating {
    let value: UInt8
    func bytes(count: Int) throws -> [UInt8] { [UInt8](repeating: value, count: count) }
}

actor AuthenticationServiceDouble: AuthenticationServicing {
    nonisolated let availability: AuthenticationAvailability
    var signInResult: Result<AuthUserProfile, Error>
    var restoreResult: Result<AuthUserProfile?, Error>
    var retryResult: Result<AuthUserProfile, Error>
    var signOutResult = SignOutResult(localSessionRemoved: true, remoteRevocationFailed: false)
    private(set) var signInCount = 0
    private(set) var retryCount = 0

    init(
        availability: AuthenticationAvailability = .configured,
        signInResult: Result<AuthUserProfile, Error>,
        restoreResult: Result<AuthUserProfile?, Error> = .success(nil),
        retryResult: Result<AuthUserProfile, Error>? = nil
    ) {
        self.availability = availability
        self.signInResult = signInResult
        self.restoreResult = restoreResult
        self.retryResult = retryResult ?? signInResult
    }

    func signIn(progress: @escaping @MainActor @Sendable (AuthenticationProgress) -> Void) async throws -> AuthUserProfile {
        signInCount += 1
        await progress(.preparingAuthorization)
        return try signInResult.get()
    }

    func restoreSession(progress: @escaping @MainActor @Sendable (AuthenticationProgress) -> Void) async throws -> AuthUserProfile? {
        await progress(.restoring)
        return try restoreResult.get()
    }

    func retryProfile() async throws -> AuthUserProfile {
        retryCount += 1
        return try retryResult.get()
    }

    func signOut() async -> SignOutResult { signOutResult }
    func cancel() async {}

    func counts() -> (Int, Int) { (signInCount, retryCount) }
}
