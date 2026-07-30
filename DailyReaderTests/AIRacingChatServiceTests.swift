import XCTest
@testable import DailyReader

final class AIRacingChatServiceTests: XCTestCase {
    func testFirstLaneWithVisibleTextWinsLogicalProviderAndCancelsLosers() async throws {
        let recorder = RacingTransportRecorder()
        let transport = StubRacingTransport(
            scripts: [
                "slow": [
                    .event(.thinking, delay: .milliseconds(5)),
                    .event(.text("慢回答"), delay: .milliseconds(180))
                ],
                "fast": [
                    .event(.thinking, delay: .milliseconds(10)),
                    .event(.text("快回答"), delay: .milliseconds(20)),
                    .event(.finished(.stop), delay: .zero)
                ],
                "third": [
                    .event(.text("第三条回答"), delay: .milliseconds(250))
                ]
            ],
            recorder: recorder
        )
        let service = AIRacingChatService(transport: transport)

        let events = try await collect(
            service.streamReply(
                providers: [provider(laneID: "slow"), provider(laneID: "fast"), provider(laneID: "third")],
                messages: [AIChatMessage(role: .user, content: "问题")],
                articleContext: nil
            )
        )

        XCTAssertEqual(
            events.first,
            .providerSelected(id: AIConfigurationStore.defaultProviderID, name: "默认服务")
        )
        XCTAssertTrue(events.contains(.thinking))
        XCTAssertTrue(events.contains(.text("快回答")))
        XCTAssertFalse(events.contains(.text("慢回答")))
        XCTAssertFalse(events.contains(.text("第三条回答")))
        await waitForCancellation(of: ["slow", "third"], recorder: recorder)
    }

    func testReasoningAndWhitespaceOnlyLanesCannotWin() async throws {
        let transport = StubRacingTransport(
            scripts: [
                "reasoning": [
                    .event(.thinking, delay: .zero),
                    .event(.finished(.length), delay: .milliseconds(5))
                ],
                "whitespace": [
                    .event(.text("  \n"), delay: .milliseconds(3)),
                    .event(.finished(.stop), delay: .milliseconds(3))
                ],
                "answer": [
                    .event(.text("可见正文"), delay: .milliseconds(15)),
                    .event(.finished(.stop), delay: .zero)
                ]
            ],
            recorder: RacingTransportRecorder()
        )

        let events = try await collect(
            AIRacingChatService(transport: transport).streamReply(
                providers: [
                    provider(laneID: "reasoning"),
                    provider(laneID: "whitespace"),
                    provider(laneID: "answer")
                ],
                messages: [],
                articleContext: nil
            )
        )

        XCTAssertEqual(
            events.first,
            .providerSelected(id: AIConfigurationStore.defaultProviderID, name: "默认服务")
        )
        XCTAssertTrue(events.contains(.text("可见正文")))
        XCTAssertFalse(events.contains(.text("  \n")))
    }

    func testNearlySimultaneousVisibleTextSelectsExactlyOneWinner() async throws {
        let transport = StubRacingTransport(
            scripts: [
                "one": [.event(.text("一号"), delay: .milliseconds(5))],
                "two": [.event(.text("二号"), delay: .milliseconds(5))],
                "three": [.event(.text("三号"), delay: .milliseconds(5))]
            ],
            recorder: RacingTransportRecorder()
        )

        let events = try await collect(
            AIRacingChatService(transport: transport).streamReply(
                providers: [provider(laneID: "one"), provider(laneID: "two"), provider(laneID: "three")],
                messages: [],
                articleContext: nil
            )
        )

        XCTAssertEqual(events.filter {
            if case .providerSelected = $0 { return true }
            return false
        }.count, 1)
        let visibleAnswers = events.compactMap { event -> String? in
            if case .text(let text) = event { return text }
            return nil
        }
        XCTAssertEqual(visibleAnswers.count, 1)
        XCTAssertTrue(["一号", "二号", "三号"].contains(visibleAnswers[0]))
    }

    func testFailureBeforeVisibleTextDoesNotStopOtherLane() async throws {
        let transport = StubRacingTransport(
            scripts: [
                "broken": [.failure("认证失败", delay: .milliseconds(5))],
                "healthy": [.event(.text("继续成功"), delay: .milliseconds(20))]
            ],
            recorder: RacingTransportRecorder()
        )

        let events = try await collect(
            AIRacingChatService(transport: transport).streamReply(
                providers: [provider(laneID: "broken"), provider(laneID: "healthy")],
                messages: [],
                articleContext: nil
            )
        )

        XCTAssertTrue(events.contains(.providerSelected(id: AIConfigurationStore.defaultProviderID, name: "默认服务")))
        XCTAssertTrue(events.contains(.text("继续成功")))
    }

    func testAllFailuresUseFirstLaneMessageInStableOrder() async throws {
        let transport = StubRacingTransport(
            scripts: [
                "first": [.failure("首选线路失败", delay: .milliseconds(20))],
                "second": [.failure("第二线路失败", delay: .milliseconds(5))]
            ],
            recorder: RacingTransportRecorder()
        )

        do {
            _ = try await collect(
                AIRacingChatService(transport: transport).streamReply(
                    providers: [provider(laneID: "first"), provider(laneID: "second")],
                    messages: [],
                    articleContext: nil
                )
            )
            XCTFail("Expected all lanes to fail")
        } catch let error as AIChatError {
            XCTAssertEqual(error, .allProvidersFailed(2, "AI 服务不可用：首选线路失败"))
        }
    }

    func testWinnerFailureAfterVisibleTextFinishesWithError() async throws {
        let transport = StubRacingTransport(
            scripts: [
                "winner": [
                    .event(.text("部分正文"), delay: .zero),
                    .failure("连接中断", delay: .milliseconds(5))
                ],
                "loser": [.event(.text("更晚正文"), delay: .seconds(1))]
            ],
            recorder: RacingTransportRecorder()
        )

        do {
            _ = try await collect(
                AIRacingChatService(transport: transport).streamReply(
                    providers: [provider(laneID: "winner"), provider(laneID: "loser")],
                    messages: [],
                    articleContext: nil
                )
            )
            XCTFail("Expected winner failure to propagate")
        } catch let error as AIChatError {
            XCTAssertEqual(error, .transport("连接中断"))
        }
    }

    func testConnectionUsesVisibleTextRaceAndCancelsOtherLanes() async throws {
        let recorder = RacingTransportRecorder()
        let transport = StubRacingTransport(
            scripts: [
                "reasoning": [.event(.thinking, delay: .zero), .event(.text("稍后"), delay: .seconds(1))],
                "winner": [.event(.text("OK"), delay: .milliseconds(10))],
                "slow": [.event(.text("慢"), delay: .seconds(1))]
            ],
            recorder: recorder
        )

        try await AIRacingChatService(transport: transport).testConnection(
            providers: [
                provider(laneID: "reasoning"),
                provider(laneID: "winner"),
                provider(laneID: "slow")
            ]
        )

        await waitForCancellation(of: ["reasoning", "slow"], recorder: recorder)
    }

    func testCancellingOuterStreamCancelsAllLanes() async throws {
        let recorder = RacingTransportRecorder()
        let transport = StubRacingTransport(
            scripts: [
                "one": [.event(.text("很晚"), delay: .seconds(2))],
                "two": [.event(.text("也很晚"), delay: .seconds(2))]
            ],
            recorder: recorder
        )
        let stream = AIRacingChatService(transport: transport).streamReply(
            providers: [provider(laneID: "one"), provider(laneID: "two")],
            messages: [],
            articleContext: nil
        )
        let consumer = Task {
            for try await _ in stream {}
        }

        try await Task.sleep(for: .milliseconds(30))
        consumer.cancel()
        _ = await consumer.result
        await waitForCancellation(of: ["one", "two"], recorder: recorder)
    }

    private func collect(_ stream: AsyncThrowingStream<AIStreamEvent, Error>) async throws -> [AIStreamEvent] {
        var events: [AIStreamEvent] = []
        for try await event in stream {
            events.append(event)
        }
        return events
    }

    private func waitForCancellation(
        of expected: Set<String>,
        recorder: RacingTransportRecorder
    ) async {
        for _ in 0..<50 {
            if await recorder.cancelledIDs().isSuperset(of: expected) { break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        let cancelledIDs = await recorder.cancelledIDs()
        XCTAssertTrue(cancelledIDs.isSuperset(of: expected), "Expected cancellations: \(expected), got: \(cancelledIDs)")
    }

    private func provider(laneID: String) -> AIProviderRuntimeConfiguration {
        AIProviderRuntimeConfiguration(
            providerID: AIConfigurationStore.defaultProviderID,
            providerName: "默认服务",
            laneID: laneID,
            configuration: AIConfiguration(
                endpoint: "https://example.com/v1",
                model: laneID,
                allowsSearchTools: true
            ),
            apiKey: laneID + "-key"
        )
    }
}

private enum RacingScriptStep: Sendable {
    case event(AIStreamEvent, delay: Duration)
    case failure(String, delay: Duration)
}

private actor RacingTransportRecorder {
    private var cancellations = Set<String>()

    func recordCancellation(_ model: String) {
        cancellations.insert(model)
    }

    func cancelledIDs() -> Set<String> {
        cancellations
    }
}

private struct StubRacingTransport: AIChatServicing {
    let scripts: [String: [RacingScriptStep]]
    let recorder: RacingTransportRecorder

    func streamReply(
        configuration: AIConfiguration,
        apiKey: String,
        messages: [AIChatMessage],
        articleContext: AIArticleContext?
    ) -> AsyncThrowingStream<AIStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for step in scripts[configuration.model] ?? [] {
                        switch step {
                        case .event(let event, let delay):
                            try await Task.sleep(for: delay)
                            continuation.yield(event)
                        case .failure(let message, let delay):
                            try await Task.sleep(for: delay)
                            throw AIChatError.transport(message)
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    await recorder.recordCancellation(configuration.model)
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func testConnection(configuration: AIConfiguration, apiKey: String) async throws {}
}
