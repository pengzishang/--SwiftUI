import XCTest
@testable import DailyReader

final class OAuthCallbackValidatorTests: XCTestCase {
    private let validator = OAuthCallbackValidator()
    private let configuration = makeTestConfiguration()

    func testValidCallbackReturnsCodeAndConsumesTransaction() throws {
        var transaction = makeTransaction()
        let code = try validator.validate(
            callbackURL: URL(string: "test-reader://oauth/callback?code=synthetic-code&state=expected-state")!,
            transaction: &transaction,
            configuration: configuration,
            now: Date(timeIntervalSince1970: 1)
        )
        XCTAssertEqual(code.value, "synthetic-code")
        XCTAssertTrue(transaction.callbackConsumed)
    }

    func testStateMismatchFails() {
        var transaction = makeTransaction()
        XCTAssertThrowsError(try validator.validate(
            callbackURL: URL(string: "test-reader://oauth/callback?code=synthetic-code&state=wrong")!,
            transaction: &transaction,
            configuration: configuration,
            now: Date(timeIntervalSince1970: 1)
        )) { error in
            XCTAssertEqual(error as? AuthenticationError, .stateMismatch)
        }
    }

    func testWrongCallbackPathFailsBeforeCodeIsExposed() {
        var transaction = makeTransaction()
        XCTAssertThrowsError(try validator.validate(
            callbackURL: URL(string: "test-reader://oauth/other?code=synthetic-code&state=expected-state")!,
            transaction: &transaction,
            configuration: configuration,
            now: Date(timeIntervalSince1970: 1)
        )) { error in
            XCTAssertEqual(error as? AuthenticationError, .invalidCallback)
        }
    }

    func testSecondCallbackFails() throws {
        var transaction = makeTransaction()
        _ = try validator.validate(
            callbackURL: URL(string: "test-reader://oauth/callback?code=first&state=expected-state")!,
            transaction: &transaction,
            configuration: configuration,
            now: Date(timeIntervalSince1970: 1)
        )
        XCTAssertThrowsError(try validator.validate(
            callbackURL: URL(string: "test-reader://oauth/callback?code=second&state=expected-state")!,
            transaction: &transaction,
            configuration: configuration,
            now: Date(timeIntervalSince1970: 2)
        )) { error in
            XCTAssertEqual(error as? AuthenticationError, .callbackAlreadyConsumed)
        }
    }

    private func makeTransaction() -> AuthorizationTransaction {
        AuthorizationTransaction(
            id: UUID(), state: "expected-state", verifier: "verifier",
            createdAt: Date(timeIntervalSince1970: 0), callbackConsumed: false
        )
    }
}
