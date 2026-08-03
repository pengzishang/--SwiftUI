import XCTest
@testable import DailyReader

@MainActor
final class AIChatViewModelTests: XCTestCase {
    func testLoadMergesSessionCreatedBeforePersistenceFinishes() async throws {
        let root = temporaryRoot()
        let sessionStore = AISessionStore(rootURL: root)
        let persisted = AIChatSession(title: "已保存对话", articleContext: AIArticleContext(id: 9, title: "旧文章", text: "正文"))
        try await sessionStore.save([persisted])

        let coordinator = AIChatCoordinator(sessionStore: sessionStore)
        coordinator.openIndependentChat()
        let newSessionID = try XCTUnwrap(coordinator.presentation?.sessionID)

        await coordinator.loadIfNeeded()

        XCTAssertNotNil(coordinator.session(id: persisted.id))
        XCTAssertNotNil(coordinator.session(id: newSessionID))
        XCTAssertEqual(coordinator.sessions.count, 2)
    }

    func testQuickPromptWithoutAvailableProviderKeepsDraftAndShowsConfigurationError() async throws {
        let name = "AIChatViewModelTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let configurationStore = AIConfigurationStore(
            defaults: defaults,
            credentialStore: StubCredentialStore(apiKey: "")
        )
        let coordinator = AIChatCoordinator(
            configurationStore: configurationStore,
            sessionStore: AISessionStore(rootURL: temporaryRoot())
        )
        coordinator.openArticleChat(context: AIArticleContext(id: 7, title: "测试文章", text: "正文"))
        let sessionID = try XCTUnwrap(coordinator.presentation?.sessionID)
        let viewModel = coordinator.makeChatViewModel(sessionID: sessionID)

        viewModel.send(prompt: "  保留的问题  ")

        XCTAssertEqual(viewModel.draft, "保留的问题")
        XCTAssertEqual(viewModel.session.draft, "保留的问题")
        XCTAssertTrue(viewModel.session.messages.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, AIChatError.noAvailableProviders.errorDescription)
        XCTAssertFalse(viewModel.canSend)
        XCTAssertFalse(viewModel.isGenerating)
    }

    func testQuickPromptImmediatelySendsWithArticleContext() async throws {
        let defaultsName = "AIChatViewModelTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let configurationStore = AIConfigurationStore(
            defaults: defaults,
            credentialStore: StubCredentialStore(apiKey: "test-key")
        )
        try configurationStore.save(
            configuration: AIConfiguration(
                endpoint: "https://example.com/v1",
                model: "test-model",
                allowsSearchTools: false
            ),
            apiKey: nil
        )
        let recorder = MessageHistoryRecorder()
        let context = AIArticleContext(id: 8, title: "快捷提问文章", text: "用于验证的文章正文")
        let coordinator = AIChatCoordinator(
            configurationStore: configurationStore,
            sessionStore: AISessionStore(rootURL: temporaryRoot()),
            chatService: RecordingChatService(recorder: recorder)
        )
        coordinator.openArticleChat(context: context)
        let sessionID = try XCTUnwrap(coordinator.presentation?.sessionID)
        let viewModel = coordinator.makeChatViewModel(sessionID: sessionID)

        viewModel.send(prompt: "  用三句话总结这篇文章  ")

        XCTAssertEqual(viewModel.session.messages.first?.role, .user)
        XCTAssertEqual(viewModel.session.messages.first?.content, "用三句话总结这篇文章")
        XCTAssertEqual(viewModel.draft, "")
        XCTAssertEqual(viewModel.session.draft, "")
        await waitForGenerationToFinish(viewModel)

        let histories = await recorder.histories
        let contexts = await recorder.articleContexts
        XCTAssertEqual(histories.count, 1)
        XCTAssertEqual(histories.first?.first?.content, "用三句话总结这篇文章")
        XCTAssertEqual(contexts, [context])
    }

    func testRetryRegeneratesWithoutDuplicatingLastUserMessage() async throws {
        let defaultsName = "AIChatViewModelTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        defer { defaults.removePersistentDomain(forName: defaultsName) }

        let configurationStore = AIConfigurationStore(
            defaults: defaults,
            credentialStore: StubCredentialStore(apiKey: "test-key")
        )
        try configurationStore.save(
            configuration: AIConfiguration(
                endpoint: "https://example.com/v1",
                model: "test-model",
                allowsSearchTools: false
            ),
            apiKey: nil
        )

        let recorder = MessageHistoryRecorder()
        let coordinator = AIChatCoordinator(
            configurationStore: configurationStore,
            sessionStore: AISessionStore(rootURL: temporaryRoot()),
            chatService: RecordingChatService(recorder: recorder)
        )
        coordinator.openIndependentChat()
        let sessionID = try XCTUnwrap(coordinator.presentation?.sessionID)
        let viewModel = coordinator.makeChatViewModel(sessionID: sessionID)

        viewModel.updateDraft("同一个问题")
        viewModel.send()
        await waitForGenerationToFinish(viewModel)
        viewModel.retryLast()
        await waitForGenerationToFinish(viewModel)

        XCTAssertEqual(viewModel.session.messages.filter { $0.role == .user }.count, 1)
        XCTAssertEqual(viewModel.session.messages.filter { $0.role == .assistant }.count, 1)
        XCTAssertEqual(viewModel.session.messages.first?.content, "同一个问题")

        let histories = await recorder.histories
        XCTAssertEqual(histories.count, 2)
        XCTAssertEqual(histories[1].filter { $0.role == .user }.count, 1)
    }

    func testAssistantMessagePersistsLogicalProviderNameInsteadOfLaneID() async throws {
        let defaultsName = "AIChatViewModelTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let defaultProvider = AIProviderProfile(
            id: AIConfigurationStore.defaultProviderID,
            name: "默认服务",
            lanes: [
                AIProviderLaneProfile(
                    id: "winner-lane",
                    configuration: AIConfiguration(
                        endpoint: "https://example.com/v1",
                        model: "winner-lane",
                        allowsSearchTools: false
                    )
                )
            ],
            source: .builtIn
        )
        let configurationStore = AIConfigurationStore(
            defaults: defaults,
            credentialStore: MappedStubCredentialStore(values: ["winner-lane": "test-key"]),
            builtInProviders: [defaultProvider]
        )
        let coordinator = AIChatCoordinator(
            configurationStore: configurationStore,
            sessionStore: AISessionStore(rootURL: temporaryRoot()),
            chatService: RecordingChatService(recorder: MessageHistoryRecorder())
        )
        coordinator.openIndependentChat()
        let sessionID = try XCTUnwrap(coordinator.presentation?.sessionID)
        let viewModel = coordinator.makeChatViewModel(sessionID: sessionID)

        viewModel.updateDraft("逻辑服务归属")
        viewModel.send()
        await waitForGenerationToFinish(viewModel)

        let assistant = try XCTUnwrap(viewModel.session.messages.last(where: { $0.role == .assistant }))
        XCTAssertEqual(assistant.providerName, "默认服务")
        XCTAssertNotEqual(assistant.providerName, "winner-lane")
    }

    private func waitForGenerationToFinish(_ viewModel: AIChatViewModel) async {
        for _ in 0..<100 where viewModel.isGenerating {
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertFalse(viewModel.isGenerating)
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}

private struct StubCredentialStore: AICredentialStoring {
    let apiKey: String

    func loadAPIKey() throws -> String? { apiKey }
    func saveAPIKey(_ value: String) throws {}
    func deleteAPIKey() throws {}
}

private struct MappedStubCredentialStore: AICredentialStoring {
    let values: [String: String]

    func loadAPIKey() throws -> String? {
        values[AIConfigurationStore.userProviderID]
    }

    func saveAPIKey(_ value: String) throws {}
    func deleteAPIKey() throws {}

    func loadAPIKey(providerID: String) throws -> String? {
        values[providerID]
    }

    func saveAPIKey(_ value: String, providerID: String) throws {}
    func deleteAPIKey(providerID: String) throws {}
}

private actor MessageHistoryRecorder {
    private(set) var histories: [[AIChatMessage]] = []
    private(set) var articleContexts: [AIArticleContext?] = []

    func record(_ messages: [AIChatMessage], articleContext: AIArticleContext?) {
        histories.append(messages)
        articleContexts.append(articleContext)
    }
}

private struct RecordingChatService: AIChatServicing {
    let recorder: MessageHistoryRecorder

    func streamReply(
        configuration: AIConfiguration,
        apiKey: String,
        messages: [AIChatMessage],
        articleContext: AIArticleContext?
    ) -> AsyncThrowingStream<AIStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await recorder.record(messages, articleContext: articleContext)
                continuation.yield(.text("回答"))
                continuation.finish()
            }
        }
    }

    func testConnection(configuration: AIConfiguration, apiKey: String) async throws {}
}
