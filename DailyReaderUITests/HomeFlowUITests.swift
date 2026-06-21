import XCTest

final class HomeFlowUITests: XCTestCase {
    func testLaunchShowsMockHomeContent() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        app.launchEnvironment = ["MOCK_SCENARIO": "latest_success"]
        app.launch()

        XCTAssertTrue(app.navigationBars["日报阅读器"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["今天，先读一篇长一点的故事"].waitForExistence(timeout: 5))
    }
}
