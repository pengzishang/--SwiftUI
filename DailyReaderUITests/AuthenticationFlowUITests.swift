import XCTest

final class AuthenticationFlowUITests: XCTestCase {
    private func launch(_ authScenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-ResetAuthSession"]
        app.launchEnvironment = [
            "MOCK_SCENARIO": "latest_success",
            "MOCK_AUTH_SCENARIO": authScenario
        ]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["我的"].waitForExistence(timeout: 5))
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.otherElements["auth.card"].waitForExistence(timeout: 5))
        return app
    }

    func testSignedOutAndSuccessNeverOpenExternalWeb() {
        let app = launch("sign_in_success")
        XCTAssertTrue(app.buttons["auth.signInButton"].exists)
        app.buttons["auth.signInButton"].tap()
        XCTAssertTrue(app.staticTexts["auth.displayName"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["auth.displayName"].label, "测试读者")
        XCTAssertFalse(app.webViews.firstMatch.exists)
    }

    func testDeniedReturnsSignedOutNotice() {
        let app = launch("authorization_denied")
        app.buttons["auth.signInButton"].tap()
        XCTAssertTrue(app.staticTexts["未获得授权，尚未登录"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["auth.signInButton"].exists)
    }

    func testCancelledReturnsNeutralNotice() {
        let app = launch("user_cancelled")
        app.buttons["auth.signInButton"].tap()
        XCTAssertTrue(app.staticTexts["已取消登录"].waitForExistence(timeout: 5))
    }

    func testTokenFailureRetriesToSuccess() {
        let app = launch("network_failure_then_success")
        app.buttons["auth.signInButton"].tap()
        XCTAssertTrue(app.buttons["auth.retryButton"].waitForExistence(timeout: 5))
        app.buttons["auth.retryButton"].tap()
        XCTAssertTrue(app.staticTexts["auth.displayName"].waitForExistence(timeout: 5))
    }

    func testSignedInRestoreAndSignOutConfirmation() {
        let app = launch("restored_signed_in")
        XCTAssertTrue(app.staticTexts["auth.displayName"].waitForExistence(timeout: 5))
        app.buttons["auth.signOutButton"].tap()
        XCTAssertTrue(app.buttons["auth.signOut.confirm"].waitForExistence(timeout: 5))
        app.buttons["auth.signOut.confirm"].tap()
        XCTAssertTrue(app.buttons["auth.signInButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["me.segment.favorites"].exists)
        XCTAssertTrue(app.buttons["me.segment.read"].exists)
    }

    func testInvalidCallbackOffersFreshLogin() {
        let app = launch("invalid_callback")
        app.buttons["auth.signInButton"].tap()
        XCTAssertTrue(app.staticTexts["auth.error"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["auth.retryButton"].exists)
        XCTAssertFalse(app.staticTexts["auth.displayName"].exists)
    }

    func testServiceFailureRetriesToSuccess() {
        let app = launch("service_failure_then_success")
        app.buttons["auth.signInButton"].tap()
        XCTAssertTrue(app.buttons["auth.retryButton"].waitForExistence(timeout: 5))
        app.buttons["auth.retryButton"].tap()
        XCTAssertTrue(app.staticTexts["auth.displayName"].waitForExistence(timeout: 5))
    }

    func testSessionExpiredOffersFreshLogin() {
        let app = launch("session_expired")
        XCTAssertTrue(app.staticTexts["auth.error"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["auth.retryButton"].exists)
        XCTAssertTrue(app.buttons["me.segment.favorites"].exists)
        XCTAssertTrue(app.buttons["me.segment.read"].exists)
    }

    func testAvatarFailureKeepsSignedInControls() {
        let app = launch("avatar_failure")
        app.buttons["auth.signInButton"].tap()
        XCTAssertTrue(app.staticTexts["auth.displayName"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.images["auth.avatar"].exists)
        XCTAssertTrue(app.buttons["auth.signOutButton"].exists)
    }

    func testCancellingSignOutKeepsSession() {
        let app = launch("restored_signed_in")
        XCTAssertTrue(app.staticTexts["auth.displayName"].waitForExistence(timeout: 5))
        app.buttons["auth.signOutButton"].tap()
        XCTAssertTrue(app.buttons["auth.signOut.cancel"].waitForExistence(timeout: 5))
        app.buttons["auth.signOut.cancel"].tap()
        XCTAssertTrue(app.staticTexts["auth.displayName"].exists)
        XCTAssertTrue(app.buttons["auth.signOutButton"].exists)
    }

    func testRemoteSignOutFailureStillClearsLocalSession() {
        let app = launch("sign_out_remote_failure")
        app.buttons["auth.signInButton"].tap()
        XCTAssertTrue(app.buttons["auth.signOutButton"].waitForExistence(timeout: 5))
        app.buttons["auth.signOutButton"].tap()
        XCTAssertTrue(app.buttons["auth.signOut.confirm"].waitForExistence(timeout: 5))
        app.buttons["auth.signOut.confirm"].tap()
        XCTAssertTrue(app.staticTexts["已在本机退出"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["auth.signInButton"].exists)
    }

    func testUnconfiguredButtonCannotLaunchAuthorization() {
        let app = launch("unconfigured")
        let button = app.buttons["auth.signInButton"]
        XCTAssertTrue(button.exists)
        XCTAssertFalse(button.isEnabled)
        XCTAssertFalse(app.webViews.firstMatch.exists)
    }
}
