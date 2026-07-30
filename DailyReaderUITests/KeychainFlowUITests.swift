import XCTest

final class KeychainFlowUITests: XCTestCase {
    
    private func launchApp(scenario: String, resetCache: Bool = true, resetUserDefaults: Bool = false, mockKeychainCorrupted: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"]
        if resetCache {
            app.launchArguments.append("-ResetCache")
        }
        if resetUserDefaults {
            app.launchArguments.append("-ResetUserDefaults")
        }
        
        var environment = ["MOCK_SCENARIO": scenario]
        if mockKeychainCorrupted {
            environment["MOCK_KEYCHAIN_STATUS"] = "corrupted"
        }
        app.launchEnvironment = environment
        app.launch()
        return app
    }
    
    private func attachScreenshot(named name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Tier 1: Keychain Backup & Restore
    
    func testT1_KC_01_02_03_04_05_KeychainBackupAndSilentRecovery() {
        // 1. Launch normally and perform read, favorite and hide actions
        var app = launchApp(scenario: "latest_success", resetCache: true)
        
        // Mark first story as read and favorite it
        XCTAssertTrue(app.staticTexts["今天，先读一篇长一点的故事"].waitForExistence(timeout: 5))
        app.staticTexts["今天，先读一篇长一点的故事"].tap()
        
        // Favorite the story
        XCTAssertTrue(app.buttons["操作"].waitForExistence(timeout: 5))
        app.buttons["操作"].tap()
        XCTAssertTrue(app.buttons["收藏"].waitForExistence(timeout: 5))
        app.buttons["收藏"].tap()
        
        // Return to home
        app.navigationBars.firstMatch.buttons.firstMatch.tap()
        
        // Hide the second story (SwiftUI 里的温柔边界)
        XCTAssertTrue(app.staticTexts["SwiftUI 里的温柔边界"].waitForExistence(timeout: 5))
        app.staticTexts["SwiftUI 里的温柔边界"].swipeLeft()
        XCTAssertTrue(app.buttons["不感兴趣"].waitForExistence(timeout: 5))
        app.buttons["不感兴趣"].tap()
        
        // Verify second story is gone
        XCTAssertFalse(app.staticTexts["SwiftUI 里的温柔边界"].exists)
        
        // 2. Kill and relaunch app with -ResetUserDefaults to simulate uninstall/reinstall
        // This will clear sandboxed UserDefaults but preserve Keychain
        app = launchApp(scenario: "latest_success", resetCache: false, resetUserDefaults: true)
        
        // Verify silent recovery works:
        // - SwiftUI 里的温柔边界 remains hidden (filtered out)
        XCTAssertFalse(app.staticTexts["SwiftUI 里的温柔边界"].exists)
        
        // - "今天，先读一篇长一点的故事" is greyed out/still marked as read (which we can check by navigating to Me)
        let meTab = app.tabBars.buttons["我的"]
        XCTAssertTrue(meTab.waitForExistence(timeout: 5))
        meTab.tap()
        
        // Verify that the restored favorite story is listed in "收藏" tab
        XCTAssertTrue(app.collectionViews["me.favorites.list"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["今天，先读一篇长一点的故事"].exists)
        
        // Verify that it is also in the "已读" tab
        app.buttons["me.segment.read"].tap()
        XCTAssertTrue(app.collectionViews["me.read.list"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["今天，先读一篇长一点的故事"].exists)
        
        attachScreenshot(named: "keychain-recovery-success", app: app)
    }

    // MARK: - Tier 2: Boundary & Exceptions
    
    func testT2_KC_02_KeychainCorruptionDefense() {
        // 1. Create a valid favorite item first so Keychain has data
        var app = launchApp(scenario: "latest_success", resetCache: true)
        XCTAssertTrue(app.staticTexts["今天，先读一篇长一点的故事"].waitForExistence(timeout: 5))
        app.staticTexts["今天，先读一篇长一点的故事"].tap()
        app.buttons["操作"].tap()
        app.buttons["收藏"].tap()
        app.navigationBars.firstMatch.buttons.firstMatch.tap()
        
        // 2. Launch with corrupted status to verify elegant recovery
        app = launchApp(scenario: "latest_success", resetCache: false, resetUserDefaults: true, mockKeychainCorrupted: true)
        
        // App should not crash and should start clean
        XCTAssertTrue(app.navigationBars["日报阅读器"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["今天，先读一篇长一点的故事"].exists)
        
        // Go to Me, Favorites list should be empty
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.staticTexts["暂无收藏内容"].waitForExistence(timeout: 5))
    }

    // MARK: - Tier 3: Combination Tests (Combos)
    
    func testT3_COMBO_01_HotListReadingAndMeRead联动() {
        let app = launchApp(scenario: "answers_success", resetCache: true)
        
        // Go to Hot tab
        let hotTab = app.tabBars.buttons["热榜"]
        XCTAssertTrue(hotTab.waitForExistence(timeout: 5))
        hotTab.tap()
        
        // Tap first hot question
        XCTAssertTrue(app.staticTexts["热榜测试标题 1：这是一个关于 Swift 编程语言的精选讨论问题？"].waitForExistence(timeout: 5))
        app.staticTexts["热榜测试标题 1：这是一个关于 Swift 编程语言的精选讨论问题？"].tap()
        
        // Tap first answer to read it
        let firstAnswerRow = app.buttons.matching(identifier: "answers.row_0").firstMatch
        XCTAssertTrue(firstAnswerRow.waitForExistence(timeout: 5))
        firstAnswerRow.tap()
        
        // Wait for detail web view to show up
        XCTAssertTrue(app.webViews["answerDetail.webView"].waitForExistence(timeout: 5))
        
        // Navigate back to answers
        app.navigationBars.firstMatch.buttons.firstMatch.tap()
        // Navigate back to hot list
        app.navigationBars.firstMatch.buttons.firstMatch.tap()
        
        // Go to Me tab
        let meTab = app.tabBars.buttons["我的"]
        XCTAssertTrue(meTab.waitForExistence(timeout: 5))
        meTab.tap()
        
        // Switch to Read tab
        app.buttons["me.segment.read"].tap()
        
        // The read list should contain the question title
        XCTAssertTrue(app.staticTexts["热榜测试标题 1：这是一个关于 Swift 编程语言的精选讨论问题？"].waitForExistence(timeout: 5))
        
        // Go back to Hot tab
        hotTab.tap()
        // Check if the title text color is grayed out (cannot verify color directly, but we can verify it still exists)
        XCTAssertTrue(app.staticTexts["热榜测试标题 1：这是一个关于 Swift 编程语言的精选讨论问题？"].exists)
        
        attachScreenshot(named: "combo-01-success", app: app)
    }

    func testT3_COMBO_03_SearchAndUnfavoriteLinkage() {
        let app = launchApp(scenario: "latest_success", resetCache: true)
        
        // Populate a favorite
        populateFavoriteAndRead(app: app)
        
        // Go to Me tab
        app.tabBars.buttons["我的"].tap()
        
        // Search for "长故事"
        let searchField = app.textFields["me.searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("长故事")
        
        // Verify it displays the item
        let row = app.staticTexts["今天，先读一篇长一点的故事"]
        XCTAssertTrue(row.exists)
        
        // Tap row to enter detail page
        row.tap()
        
        // Unfavorite
        app.buttons["操作"].tap()
        app.buttons["收藏"].tap()
        
        // Back to Me
        app.navigationBars.firstMatch.buttons.firstMatch.tap()
        
        // Verify list is empty
        XCTAssertFalse(app.staticTexts["今天，先读一篇长一点的故事"].exists)
        // Verify search field STILL retains the search term "长故事"
        XCTAssertEqual(searchField.value as? String, "长故事")
    }

    func testT3_COMBO_04_ColdPalaceLinkage() {
        let app = launchApp(scenario: "latest_success", resetCache: true)
        
        // Read the first article
        XCTAssertTrue(app.staticTexts["今天，先读一篇长一点的故事"].waitForExistence(timeout: 5))
        app.staticTexts["今天，先读一篇长一点的故事"].tap()
        app.navigationBars.firstMatch.buttons.firstMatch.tap()
        
        // Go to Me tab -> Read tab, verify it is there
        app.tabBars.buttons["我的"].tap()
        app.buttons["me.segment.read"].tap()
        XCTAssertTrue(app.staticTexts["今天，先读一篇长一点的故事"].exists)
        
        // Go back to Home
        app.tabBars.buttons.element(boundBy: 0).tap()
        
        // Swipe left on "今天，先读一篇长一点的故事" and hide it
        app.staticTexts["今天，先读一篇长一点的故事"].swipeLeft()
        app.buttons["不感兴趣"].tap()
        
        // Go back to Me tab -> Read tab, verify it is hidden!
        app.tabBars.buttons["我的"].tap()
        XCTAssertFalse(app.staticTexts["今天，先读一篇长一点的故事"].exists)
    }

    private func populateFavoriteAndRead(app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["今天，先读一篇长一点的故事"].waitForExistence(timeout: 5))
        app.staticTexts["今天，先读一篇长一点的故事"].tap()

        XCTAssertTrue(app.buttons["操作"].waitForExistence(timeout: 5))
        app.buttons["操作"].tap()
        XCTAssertTrue(app.buttons["收藏"].waitForExistence(timeout: 5))
        app.buttons["收藏"].tap()

        app.navigationBars.firstMatch.buttons.firstMatch.tap()
    }
}
