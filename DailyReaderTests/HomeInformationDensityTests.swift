import XCTest
@testable import DailyReader

final class HomeInformationDensityTests: XCTestCase {
    func testMissingStoredValueDefaultsToMedium() {
        XCTAssertEqual(HomeInformationDensity(storedValue: nil), .medium)
    }

    func testUnknownStoredValueFallsBackToMedium() {
        XCTAssertEqual(HomeInformationDensity(storedValue: "unknown"), .medium)
    }

    func testAllStoredValuesRoundTrip() {
        for density in HomeInformationDensity.allCases {
            XCTAssertEqual(HomeInformationDensity(storedValue: density.rawValue), density)
        }
    }

    func testHighDensityDoesNotDisplayMetrics() {
        XCTAssertFalse(HomeInformationDensity.high.displaysMetrics)
        XCTAssertTrue(HomeInformationDensity.low.displaysMetrics)
        XCTAssertTrue(HomeInformationDensity.medium.displaysMetrics)
    }

    func testUserFacingLabelsRemainStable() {
        XCTAssertEqual(HomeInformationDensity.low.accessibilityDescription, "沉浸，低密度，大图与完整预览")
        XCTAssertEqual(HomeInformationDensity.medium.accessibilityDescription, "标准，中密度，信息均衡")
        XCTAssertEqual(HomeInformationDensity.high.accessibilityDescription, "速览，高密度，更多标题")
    }
}
