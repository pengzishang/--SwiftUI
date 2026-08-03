import XCTest
@testable import DailyReader

@MainActor
final class AuthenticationViewModelTests: XCTestCase {
    func testUnavailableStartsFailClosed() {
        let service = AuthenticationServiceDouble(
            availability: .unconfigured(.missingRequiredValues),
            signInResult: .failure(AuthenticationError.configurationUnavailable)
        )
        let viewModel = AuthenticationViewModel(service: service)
        XCTAssertEqual(viewModel.state, .unconfigured)
    }

    func testAppEnvironmentIgnoresMockScenarioWithoutUITestMode() {
        let viewModel = AppEnvironment.makeAuthenticationViewModel(
            arguments: [],
            environment: ["MOCK_AUTH_SCENARIO": "sign_in_success"]
        )

        XCTAssertEqual(viewModel.state, .unconfigured)
    }

    func testAppEnvironmentUsesFixtureOnlyInUITestMode() {
        let viewModel = AppEnvironment.makeAuthenticationViewModel(
            arguments: ["-UITestMode"],
            environment: ["MOCK_AUTH_SCENARIO": "sign_in_success"]
        )

        XCTAssertEqual(viewModel.state, .signedOut(notice: nil))
    }

    func testSignInSuccessShowsProfile() async throws {
        let profile = try AuthUserProfile(subject: "user", displayName: "Reader", avatarURL: nil)
        let service = AuthenticationServiceDouble(signInResult: .success(profile))
        let viewModel = AuthenticationViewModel(service: service)

        viewModel.signIn()
        try await waitUntil { viewModel.state == .signedIn(profile) }
    }

    func testCancellationReturnsNeutralSignedOutState() async throws {
        let service = AuthenticationServiceDouble(signInResult: .failure(AuthenticationError.userCancelled))
        let viewModel = AuthenticationViewModel(service: service)

        viewModel.signIn()
        try await waitUntil { viewModel.state == .signedOut(notice: "已取消登录") }
    }

    func testProfileFailureRetryUsesProfileIntent() async throws {
        let profile = try AuthUserProfile(subject: "user", displayName: "Reader", avatarURL: nil)
        let service = AuthenticationServiceDouble(
            signInResult: .failure(AuthenticationError.profileFailure),
            retryResult: .success(profile)
        )
        let viewModel = AuthenticationViewModel(service: service)

        viewModel.signIn()
        try await waitUntil {
            if case .retryableFailure = viewModel.state { return true }
            return false
        }
        viewModel.retry()
        try await waitUntil { viewModel.state == .signedIn(profile) }
        let counts = await service.counts()
        XCTAssertEqual(counts.1, 1)
    }

    private func waitUntil(
        timeout: TimeInterval = 1,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(condition())
    }
}
