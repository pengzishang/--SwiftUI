import XCTest
@testable import DailyReader

final class AIChatServiceTests: XCTestCase {
    func testParsesTextDeltaFromSSEPayload() throws {
        let data = try XCTUnwrap("""
        {"choices":[{"delta":{"content":"你好"}}]}
        """.data(using: .utf8))

        XCTAssertEqual(OpenAICompatibleChatService.parseStreamPayload(data), [.text("你好")])
    }

    func testParsesToolStatusAndCitationsOnlyWhenReturned() throws {
        let data = try XCTUnwrap("""
        {
          "choices":[{"delta":{"tool_calls":[{"id":"call_1"}]}}],
          "citations":[{"title":"研究报告","url":"https://example.com/report","snippet":"摘要"}]
        }
        """.data(using: .utf8))

        let events = OpenAICompatibleChatService.parseStreamPayload(data)

        XCTAssertTrue(events.contains(.searchStatus("正在使用搜索工具")))
        XCTAssertTrue(events.contains(.searchStatus("已检索 1 个来源")))
        guard case .citations(let citations) = events.first(where: {
            if case .citations = $0 { return true }
            return false
        }) else {
            return XCTFail("Expected citations event")
        }
        XCTAssertEqual(citations.first?.title, "研究报告")
        XCTAssertEqual(citations.first?.url, "https://example.com/report")
    }

    func testDropsNonWebCitationURLs() throws {
        let data = try XCTUnwrap("""
        {"citations":[{"title":"本地文件","url":"file:///tmp/source"},{"title":"网页","url":"https://example.com"}]}
        """.data(using: .utf8))

        let events = OpenAICompatibleChatService.parseStreamPayload(data)
        guard case .citations(let citations) = events.first else {
            return XCTFail("Expected citations event")
        }
        XCTAssertEqual(citations.map(\.title), ["网页"])
    }

    func testDoesNotFabricateSearchStatusForPlainText() throws {
        let data = try XCTUnwrap("""
        {"choices":[{"delta":{"content":"普通回答"}}]}
        """.data(using: .utf8))

        let events = OpenAICompatibleChatService.parseStreamPayload(data)

        XCTAssertEqual(events, [.text("普通回答")])
    }

    func testConvertsReasoningContentToGenericThinkingStatus() throws {
        let data = try XCTUnwrap("""
        {"choices":[{"delta":{"reasoning_content":"private reasoning"}}]}
        """.data(using: .utf8))

        XCTAssertEqual(OpenAICompatibleChatService.parseStreamPayload(data), [.thinking])
    }

    func testParsesFinishReasons() throws {
        let stop = try XCTUnwrap("""
        {"choices":[{"delta":{},"finish_reason":"stop"}]}
        """.data(using: .utf8))
        let length = try XCTUnwrap("""
        {"choices":[{"delta":{},"finish_reason":"length"}]}
        """.data(using: .utf8))

        XCTAssertEqual(OpenAICompatibleChatService.parseStreamPayload(stop), [.finished(.stop)])
        XCTAssertEqual(OpenAICompatibleChatService.parseStreamPayload(length), [.finished(.length)])
    }
}
