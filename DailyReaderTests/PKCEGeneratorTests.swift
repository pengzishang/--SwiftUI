import XCTest
@testable import DailyReader

final class PKCEGeneratorTests: XCTestCase {
    func testRFC7636S256Vector() {
        XCTAssertEqual(
            SystemPKCEGenerator.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"),
            "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        )
    }

    func testGeneratedStateAndVerifierUseBase64URLAlphabet() throws {
        let generator = SystemPKCEGenerator(random: FixedRandomGenerator(value: 0xAB))
        let state = try generator.generateState()
        let pair = try generator.generatePair()

        XCTAssertEqual(state.count, 43)
        XCTAssertTrue((43...128).contains(pair.verifier.count))
        XCTAssertNil(state.range(of: "[^A-Za-z0-9_-]", options: .regularExpression))
        XCTAssertNil(pair.verifier.range(of: "[^A-Za-z0-9_-]", options: .regularExpression))
    }
}
