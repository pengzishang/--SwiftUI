import XCTest
@testable import DailyReader

final class AIArticleContextBuilderTests: XCTestCase {
    func testExtractsReadableTextAndRemovesMarkup() {
        let context = AIArticleContextBuilder.make(
            id: 1,
            title: "测试文章",
            html: "<style>.hidden{display:none}</style><p>第一段&nbsp;内容</p><script>alert(1)</script><p>第二段</p>",
            sourceURL: "https://example.com/1"
        )

        XCTAssertTrue(context.text.contains("第一段 内容"))
        XCTAssertTrue(context.text.contains("第二段"))
        XCTAssertFalse(context.text.contains("alert"))
        XCTAssertFalse(context.text.contains("<p>"))
    }

    func testLongContextIsTruncatedAndPreservesFocusedSelection() {
        let selection = "需要保留的重点句子"
        let body = String(repeating: "开头内容", count: 4_000) + selection + String(repeating: "结尾内容", count: 4_000)

        let context = AIArticleContextBuilder.make(
            id: 2,
            title: "长文章",
            html: "<p>\(body)</p>",
            sourceURL: nil,
            focusedSelection: selection
        )

        XCTAssertTrue(context.isTruncated)
        XCTAssertTrue(context.text.contains(selection))
        XCTAssertLessThanOrEqual(context.text.count, AIArticleContextBuilder.maximumCharacters + 100)
    }

    func testPlainTextBuilderPreservesLiteralAngleBrackets() {
        let context = AIArticleContextBuilder.make(
            id: 3,
            title: "纯文本",
            plainText: "比较 2 < 3 与 5 > 4",
            sourceURL: nil
        )

        XCTAssertEqual(context.text, "比较 2 < 3 与 5 > 4")
    }

    func testConfigurationBuildsChatCompletionsURL() {
        XCTAssertEqual(
            AIConfiguration.endpointURL(from: "https://api.example.com/v1")?.absoluteString,
            "https://api.example.com/v1/chat/completions"
        )
        XCTAssertEqual(
            AIConfiguration.endpointURL(from: "https://api.example.com/v1/chat/completions")?.absoluteString,
            "https://api.example.com/v1/chat/completions"
        )
        XCTAssertEqual(
            AIConfiguration.endpointURL(from: "https://api.example.com/v1/?tenant=reader")?.absoluteString,
            "https://api.example.com/v1/chat/completions?tenant=reader"
        )
        XCTAssertNil(AIConfiguration.endpointURL(from: "http://api.example.com/v1"))
    }
}
