import Foundation

protocol AIRacingChatServicing: Sendable {
    func streamReply(
        providers: [AIProviderRuntimeConfiguration],
        messages: [AIChatMessage],
        articleContext: AIArticleContext?
    ) -> AsyncThrowingStream<AIStreamEvent, Error>

    func testConnection(providers: [AIProviderRuntimeConfiguration]) async throws
}

struct AIRacingChatService: AIRacingChatServicing, Sendable {
    private actor TaskRegistry {
        private enum CancellationState {
            case inactive
            case all
            case allExcept(Int)
        }

        private var tasks: [Int: Task<Void, Never>] = [:]
        private var cancellationState = CancellationState.inactive

        func register(_ task: Task<Void, Never>, index: Int) {
            tasks[index] = task
            switch cancellationState {
            case .inactive:
                break
            case .all:
                task.cancel()
            case .allExcept(let winnerIndex):
                if index != winnerIndex { task.cancel() }
            }
        }

        func cancelAll(except winnerIndex: Int? = nil) {
            cancellationState = winnerIndex.map(CancellationState.allExcept) ?? .all
            for (index, task) in tasks where index != winnerIndex {
                task.cancel()
            }
        }
    }

    private enum CandidateEvent: Sendable {
        case event(providerIndex: Int, AIStreamEvent)
        case completed(providerIndex: Int, producedText: Bool)
        case failed(providerIndex: Int, message: String)
    }

    private let transport: AIChatServicing

    init(transport: AIChatServicing = OpenAICompatibleChatService()) {
        self.transport = transport
    }

    func testConnection(providers: [AIProviderRuntimeConfiguration]) async throws {
        let stream = streamReply(
            providers: providers,
            messages: [AIChatMessage(role: .user, content: "Reply with OK.")],
            articleContext: nil
        )
        for try await event in stream {
            if case .text(let text) = event,
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return
            }
        }
        throw AIChatError.emptyResponse
    }

    func streamReply(
        providers: [AIProviderRuntimeConfiguration],
        messages: [AIChatMessage],
        articleContext: AIArticleContext?
    ) -> AsyncThrowingStream<AIStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            guard !providers.isEmpty else {
                continuation.finish(throwing: AIChatError.noAvailableProviders)
                return
            }

            let taskRegistry = TaskRegistry()
            let parentTask = Task {
                let multiplexed = AsyncStream<CandidateEvent> { eventContinuation in
                    for (index, provider) in providers.enumerated() {
                        let task = Task {
                            var producedText = false
                            do {
                                for try await event in transport.streamReply(
                                    configuration: provider.configuration,
                                    apiKey: provider.apiKey,
                                    messages: messages,
                                    articleContext: articleContext
                                ) {
                                    try Task.checkCancellation()
                                    if case .text(let value) = event,
                                       !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        producedText = true
                                    }
                                    eventContinuation.yield(.event(providerIndex: index, event))
                                }
                                eventContinuation.yield(.completed(providerIndex: index, producedText: producedText))
                            } catch is CancellationError {
                                // A cancelled loser is expected and should not affect the winner.
                            } catch {
                                eventContinuation.yield(
                                    .failed(
                                        providerIndex: index,
                                        message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                                    )
                                )
                            }
                        }
                        Task { await taskRegistry.register(task, index: index) }
                    }
                    eventContinuation.onTermination = { _ in
                        Task { await taskRegistry.cancelAll() }
                    }
                }

                var iterator = multiplexed.makeAsyncIterator()
                var winnerIndex: Int?
                var buffers = Array(repeating: [AIStreamEvent](), count: providers.count)
                var failures = Array<String?>(repeating: nil, count: providers.count)
                var finishedCandidates = Set<Int>()

                while let candidate = await iterator.next() {
                    if Task.isCancelled {
                        await taskRegistry.cancelAll()
                        continuation.finish(throwing: CancellationError())
                        return
                    }
                    switch candidate {
                    case .event(let index, let event):
                        if let winnerIndex {
                            if index == winnerIndex {
                                continuation.yield(event)
                            }
                            continue
                        }

                        if case .text(let text) = event,
                           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            winnerIndex = index
                            await taskRegistry.cancelAll(except: index)
                            let provider = providers[index]
#if DEBUG
                            print("[AI] winner lane: \(provider.laneID)")
#endif
                            continuation.yield(
                                .providerSelected(id: provider.providerID, name: provider.providerName)
                            )
                            for buffered in buffers[index] {
                                if case .finished = buffered { continue }
                                continuation.yield(buffered)
                            }
                            continuation.yield(event)
                        } else {
                            buffers[index].append(event)
                        }

                    case .completed(let index, let producedText):
                        finishedCandidates.insert(index)
                        if winnerIndex == index {
                            continuation.finish()
                            return
                        }
                        if !producedText {
                            failures[index] = "未返回可显示的正文"
                        }

                    case .failed(let index, let message):
                        finishedCandidates.insert(index)
                        failures[index] = message
                        if winnerIndex == index {
                            continuation.finish(throwing: AIChatError.transport(message))
                            return
                        }
                    }

                    if winnerIndex == nil, finishedCandidates.count == providers.count {
                        let preferred = failures.compactMap { $0 }.first
                        continuation.finish(
                            throwing: AIChatError.allProvidersFailed(
                                providers.count,
                                preferred.map { "AI 服务不可用：\($0)" }
                            )
                        )
                        return
                    }
                }

                if winnerIndex == nil {
                    continuation.finish(throwing: AIChatError.allProvidersFailed(providers.count, nil))
                } else {
                    continuation.finish()
                }
            }

            continuation.onTermination = { _ in
                parentTask.cancel()
                Task { await taskRegistry.cancelAll() }
            }
        }
    }
}
