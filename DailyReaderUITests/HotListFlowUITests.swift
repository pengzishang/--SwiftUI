import XCTest

final class HotListFlowUITests: XCTestCase {
    
    // MARK: - Helper Launch Method
    private func launchApp(scenario: String, resetCache: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        if resetCache {
            app.launchArguments.append("-ResetCache")
        }
        app.launchEnvironment = ["MOCK_SCENARIO": scenario]
        app.launch()
        return app
    }

    private func attachScreenshot(named name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func scrollUntilVisible(_ element: XCUIElement, in scrollView: XCUIElement, maxSwipes: Int = 8) {
        for _ in 0..<maxSwipes where !element.exists {
            scrollView.swipeUp()
        }
    }

    // MARK: - Tier 1: Hot List Functional Coverage
    
    func testT1_HOT_01_HotListDisplay() {
        let app = launchApp(scenario: "hot_list_success")
        
        let hotTab = app.tabBars.buttons["热榜"]
        XCTAssertTrue(hotTab.waitForExistence(timeout: 5))
        hotTab.tap()
        
        let hotListContainer = app.collectionViews["hotList.container"]
        XCTAssertTrue(hotListContainer.waitForExistence(timeout: 5))
        
        let firstHotItem = app.staticTexts["热榜测试标题 1：这是一个关于 Swift 编程语言的精选讨论问题？"]
        XCTAssertTrue(firstHotItem.waitForExistence(timeout: 5))

        let thumbnail = app.descendants(matching: .any).matching(identifier: "hotList.thumbnail").firstMatch
        XCTAssertTrue(thumbnail.waitForExistence(timeout: 5))

        let thirtiethHotItem = app.staticTexts["热榜测试标题 30：这是一个关于 Swift 编程语言的精选讨论问题？"]
        scrollUntilVisible(thirtiethHotItem, in: hotListContainer)
        XCTAssertTrue(thirtiethHotItem.exists)
        attachScreenshot(named: "hot-list-success", app: app)
    }

    func testT1_HOT_02_RankHighlighting() {
        let app = launchApp(scenario: "hot_list_success")
        
        app.tabBars.buttons["热榜"].tap()
        
        // Check for Rank 1-3 highlighted identifier
        let topRankText = app.staticTexts.matching(identifier: "hotList.rank.top3").firstMatch
        XCTAssertTrue(topRankText.waitForExistence(timeout: 5))
        
        // Check for Rank 4+ normal identifier
        let normalRankText = app.staticTexts.matching(identifier: "hotList.rank.normal").firstMatch
        XCTAssertTrue(normalRankText.waitForExistence(timeout: 5))
    }

    func testT1_HOT_03_EnterQuestionAnswersView() {
        let app = launchApp(scenario: "hot_list_success")
        
        app.tabBars.buttons["热榜"].tap()
        
        let firstHotItem = app.staticTexts["热榜测试标题 1：这是一个关于 Swift 编程语言的精选讨论问题？"]
        XCTAssertTrue(firstHotItem.waitForExistence(timeout: 5))
        firstHotItem.tap()
        
        let questionTitle = app.staticTexts["answers.questionTitle"]
        XCTAssertTrue(questionTitle.waitForExistence(timeout: 5))
        XCTAssertEqual(questionTitle.label, "热榜测试标题 1：这是一个关于 Swift 编程语言的精选讨论问题？")

        let questionExcerpt = app.staticTexts["answers.questionExcerpt"]
        XCTAssertTrue(questionExcerpt.waitForExistence(timeout: 5))
        XCTAssertEqual(questionExcerpt.label, "这是第 1 个热榜问题的摘要内容，点击可以进入精选回答列表。")
        attachScreenshot(named: "answers-question-title", app: app)
    }

    func testT1_HOT_04_AnswersListDisplay() {
        let app = launchApp(scenario: "answers_success")
        
        app.tabBars.buttons["热榜"].tap()
        
        let firstHotItem = app.staticTexts["热榜测试标题 1：这是一个关于 Swift 编程语言的精选讨论问题？"]
        XCTAssertTrue(firstHotItem.waitForExistence(timeout: 5))
        firstHotItem.tap()
        
        let answersList = app.collectionViews["answers.list"]
        XCTAssertTrue(answersList.waitForExistence(timeout: 5))
        
        let firstAnswerRow = app.buttons.matching(identifier: "answers.row_0").firstMatch
        XCTAssertTrue(firstAnswerRow.waitForExistence(timeout: 5))
    }

    func testT1_HOT_06_AnswersForbiddenShowsQuestionFallback() {
        let app = launchApp(scenario: "answers_forbidden")

        app.tabBars.buttons["热榜"].tap()

        let firstHotItem = app.staticTexts["热榜测试标题 1：这是一个关于 Swift 编程语言的精选讨论问题？"]
        XCTAssertTrue(firstHotItem.waitForExistence(timeout: 5))
        firstHotItem.tap()

        let restrictedMessage = app.staticTexts["answers.restrictedMessage"]
        XCTAssertTrue(restrictedMessage.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["接口请求失败（403）"].exists)

        let fallbackExcerpt = app.staticTexts["answers.restrictedExcerpt"]
        XCTAssertTrue(fallbackExcerpt.waitForExistence(timeout: 5))
        XCTAssertEqual(fallbackExcerpt.label, "这是第 1 个热榜问题的摘要内容，点击可以进入精选回答列表。")

        XCTAssertTrue(app.buttons["answers.openInZhihu"].exists)
    }

    func testT1_HOT_05_ViewAnswerDetail() {
        let app = launchApp(scenario: "answers_success")
        
        app.tabBars.buttons["热榜"].tap()
        app.staticTexts["热榜测试标题 1：这是一个关于 Swift 编程语言的精选讨论问题？"].tap()
        
        let firstAnswerRow = app.buttons.matching(identifier: "answers.row_0").firstMatch
        XCTAssertTrue(firstAnswerRow.waitForExistence(timeout: 5))
        firstAnswerRow.tap()
        
        let webView = app.webViews["answerDetail.webView"]
        XCTAssertTrue(webView.waitForExistence(timeout: 5))
        attachScreenshot(named: "answer-detail-webview", app: app)
    }

    // MARK: - Tier 2: Boundary & Exceptions
    
    func testT2_HOT_01_EmptyHotList() {
        let app = launchApp(scenario: "hot_list_empty")
        
        app.tabBars.buttons["热榜"].tap()
        
        let emptyStateText = app.staticTexts["今日暂无热榜内容"]
        XCTAssertTrue(emptyStateText.waitForExistence(timeout: 5))
        attachScreenshot(named: "hot-list-empty", app: app)
    }

    func testT2_HOT_02_EmptyAnswers() {
        let app = launchApp(scenario: "answers_empty")
        
        app.tabBars.buttons["热榜"].tap()
        app.staticTexts["热榜测试标题 1：这是一个关于 Swift 编程语言的精选讨论问题？"].tap()
        
        let emptyAnswersText = app.staticTexts["暂无精选回答"]
        XCTAssertTrue(emptyAnswersText.waitForExistence(timeout: 5))
        attachScreenshot(named: "answers-empty", app: app)
    }

    func testT2_HOT_03_EmptyAnswerDetail() {
        let app = launchApp(scenario: "answers_empty_body")
        
        app.tabBars.buttons["热榜"].tap()
        app.staticTexts["热榜测试标题 1：这是一个关于 Swift 编程语言的精选讨论问题？"].tap()
        
        let firstAnswerRow = app.buttons.matching(identifier: "answers.row_0").firstMatch
        XCTAssertTrue(firstAnswerRow.waitForExistence(timeout: 5))
        firstAnswerRow.tap()
        
        let emptyDetailText = app.staticTexts["回答正文加载失败或暂无内容"]
        XCTAssertTrue(emptyDetailText.waitForExistence(timeout: 5))
        attachScreenshot(named: "answers-empty-detail", app: app)
    }

    func testT2_HOT_04_HotListTimeout() {
        let app = launchApp(scenario: "hot_list_timeout")
        
        app.tabBars.buttons["热榜"].tap()
        
        let errorText = app.staticTexts["请求超时，请稍后重试"]
        XCTAssertTrue(errorText.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["重试"].exists)
        attachScreenshot(named: "hot-list-timeout", app: app)
    }

    func testT2_HOT_05_ComplexHtml() {
        let app = launchApp(scenario: "answers_complex_html")
        
        app.tabBars.buttons["热榜"].tap()
        app.staticTexts["热榜测试标题 1：这是一个关于 Swift 编程语言 of 精选讨论问题？"].firstMatch.tap()
        
        let firstAnswerRow = app.buttons.matching(identifier: "answers.row_0").firstMatch
        XCTAssertTrue(firstAnswerRow.waitForExistence(timeout: 5))
        firstAnswerRow.tap()
        
        let webView = app.webViews["answerDetail.webView"]
        XCTAssertTrue(webView.waitForExistence(timeout: 5))
    }
}
