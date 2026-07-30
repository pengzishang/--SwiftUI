import XCTest
@testable import DailyReader

final class AISessionStoreTests: XCTestCase {
    func testRoundTripsSessionsInApplicationSupportStyleStore() async throws {
        let root = temporaryRoot()
        let store = AISessionStore(rootURL: root)
        let context = AIArticleContext(id: 1, title: "文章", text: "正文")
        let session = AIChatSession(
            title: "测试会话",
            articleContext: context,
            messages: [AIChatMessage(role: .user, content: "问题")],
            draft: "草稿"
        )

        try await store.save([session])
        let loaded = try await store.load()

        XCTAssertEqual(loaded, [session])
    }

    func testStreamingMessageRecoversAsInterrupted() async throws {
        let root = temporaryRoot()
        let store = AISessionStore(rootURL: root)
        let message = AIChatMessage(role: .assistant, content: "部分回答", state: .streaming)
        let session = AIChatSession(title: "中断会话", messages: [message])

        try await store.save([session])
        let loaded = try await store.load()

        XCTAssertEqual(loaded.first?.messages.first?.state, .interrupted)
        XCTAssertEqual(loaded.first?.messages.first?.content, "部分回答")
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
