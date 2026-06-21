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

    func testOpenArticleDetailAndReturnHome() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        app.launchEnvironment = ["MOCK_SCENARIO": "latest_success"]
        app.launch()

        XCTAssertTrue(app.staticTexts["今天，先读一篇长一点的故事"].waitForExistence(timeout: 5))
        app.staticTexts["今天，先读一篇长一点的故事"].firstMatch.tap()

        XCTAssertTrue(app.navigationBars["文章详情"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["这是一篇用于 UI 测试的日报文章。它不使用官方品牌资产，只验证阅读闭环。"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["分享"].exists)

        app.navigationBars["文章详情"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["日报阅读器"].waitForExistence(timeout: 5))
    }

    func testShareSheetCanOpenAndDismissWithoutLeavingDetail() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        app.launchEnvironment = ["MOCK_SCENARIO": "latest_success"]
        app.launch()

        XCTAssertTrue(app.staticTexts["今天，先读一篇长一点的故事"].waitForExistence(timeout: 5))
        app.staticTexts["今天，先读一篇长一点的故事"].firstMatch.tap()

        XCTAssertTrue(app.navigationBars["文章详情"].waitForExistence(timeout: 5))
        app.buttons["分享"].tap()

        let activityList = app.otherElements.matching(identifier: "ActivityListView").firstMatch
        let shareSheet = app.sheets.firstMatch
        XCTAssertTrue(activityList.waitForExistence(timeout: 5) || shareSheet.waitForExistence(timeout: 1))

        if app.buttons["Close"].exists {
            app.buttons["Close"].tap()
        } else if app.buttons["取消"].exists {
            app.buttons["取消"].tap()
        } else {
            app.swipeDown()
        }

        XCTAssertTrue(app.navigationBars["文章详情"].waitForExistence(timeout: 5))
    }

    func testLoadHistoryShowsOlderStory() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        app.launchEnvironment = ["MOCK_SCENARIO": "latest_success"]
        app.launch()

        XCTAssertTrue(app.buttons["加载更早日报"].waitForExistence(timeout: 5))
        app.buttons["加载更早日报"].tap()

        XCTAssertTrue(app.staticTexts["昨天的好问题"].waitForExistence(timeout: 5))
    }
}
