import Foundation

enum AuthMockScenario: String, Sendable {
    case unconfigured
    case signedOut = "signed_out"
    case signInSuccess = "sign_in_success"
    case userCancelled = "user_cancelled"
    case authorizationDenied = "authorization_denied"
    case invalidCallback = "invalid_callback"
    case networkFailureThenSuccess = "network_failure_then_success"
    case serviceFailureThenSuccess = "service_failure_then_success"
    case restoredSignedIn = "restored_signed_in"
    case sessionExpired = "session_expired"
    case profileFailureThenSuccess = "profile_failure_then_success"
    case avatarFailure = "avatar_failure"
    case signOutRemoteFailure = "sign_out_remote_failure"

    init(value: String?) {
        self = value.flatMap(Self.init(rawValue:)) ?? .unconfigured
    }
}

actor FixtureAuthenticationService: AuthenticationServicing {
    nonisolated let availability: AuthenticationAvailability

    private let scenario: AuthMockScenario
    private var attempt = 0
    private var signedIn = false
    private let profile: AuthUserProfile

    init(scenario: AuthMockScenario) {
        self.scenario = scenario
        availability = scenario == .unconfigured ? .unconfigured(.missingRequiredValues) : .configured
        profile = try! AuthUserProfile(subject: "ui-test-user", displayName: "测试读者", avatarURL: nil)
        signedIn = scenario == .restoredSignedIn
    }

    func signIn(progress: @escaping @MainActor @Sendable (AuthenticationProgress) -> Void) async throws -> AuthUserProfile {
        guard availability == .configured else { throw AuthenticationError.configurationUnavailable }
        attempt += 1
        await progress(.preparingAuthorization)
        await Task.yield()
        await progress(.authorizing)
        await Task.yield()
        switch scenario {
        case .userCancelled: throw AuthenticationError.userCancelled
        case .authorizationDenied: throw AuthenticationError.authorizationDenied
        case .invalidCallback: throw AuthenticationError.invalidCallback
        case .networkFailureThenSuccess where attempt == 1: throw AuthenticationError.transportFailure
        case .serviceFailureThenSuccess where attempt == 1: throw AuthenticationError.serviceFailure
        default: break
        }
        await progress(.processingCallback)
        await Task.yield()
        await progress(.loadingProfile)
        await Task.yield()
        if scenario == .profileFailureThenSuccess, attempt == 1 { throw AuthenticationError.profileFailure }
        if scenario == .sessionExpired { throw AuthenticationError.invalidSession }
        signedIn = true
        return profile
    }

    func restoreSession(progress: @escaping @MainActor @Sendable (AuthenticationProgress) -> Void) async throws -> AuthUserProfile? {
        guard availability == .configured else { return nil }
        await progress(.restoring)
        await Task.yield()
        if scenario == .sessionExpired { throw AuthenticationError.invalidSession }
        return signedIn ? profile : nil
    }

    func retryProfile() async throws -> AuthUserProfile {
        attempt += 1
        if scenario == .sessionExpired { throw AuthenticationError.invalidSession }
        signedIn = true
        return profile
    }

    func signOut() async -> SignOutResult {
        signedIn = false
        return SignOutResult(
            localSessionRemoved: true,
            remoteRevocationFailed: scenario == .signOutRemoteFailure
        )
    }

    func cancel() async {}
}
