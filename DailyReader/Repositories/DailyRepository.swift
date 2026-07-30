import Foundation

actor DailyRepository: DailyRepositoryProtocol {
    private let service: DailyServiceProtocol
    private let cacheStore: CacheStore
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    init(
        service: DailyServiceProtocol,
        cacheStore: CacheStore,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.service = service
        self.cacheStore = cacheStore
        self.calendar = calendar
        self.now = now
    }

    nonisolated func loadHomeFeed() -> AsyncThrowingStream<HomeFeedEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await self.streamHomeFeed(to: continuation)
            }
        }
    }

    func refreshHomeFeed(
        current: HomeFeedSnapshot
    ) async throws -> RepositoryValue<HomeFeedSnapshot> {
        let latest = try await service.fetchLatest()
        await cacheStore.saveLatest(latest)
        let snapshot = merge(latest: latest, into: current)
        await saveHomeFeed(snapshot)
        return RepositoryValue(value: snapshot, source: .network)
    }

    func loadMore(
        before oldestDate: String,
        current: HomeFeedSnapshot
    ) async throws -> RepositoryValue<HomeFeedSnapshot> {
        let targets = historicalTargets(
            before: oldestDate,
            count: CachePolicy.historyPrefetchDayCount
        )
        guard !targets.isEmpty else {
            throw HistoryPaginationError.invalidCursor(oldestDate)
        }

        let targetDates = targets.map(\.responseDate)
        let cachedValues = await cacheStore.loadDaily(dates: targetDates)
        let missingTargets = targets.filter { cachedValues[$0.responseDate] == nil }
        let networkResult = await fetchHistoricalResponses(for: missingTargets)

        var responsesByDate = cachedValues.mapValues(\.value)
        for loaded in networkResult.responses {
            responsesByDate[loaded.target.responseDate] = loaded.response
            await cacheStore.saveDaily(loaded.response)
        }

        let orderedResponses = targetDates.compactMap { responsesByDate[$0] }
        if orderedResponses.isEmpty, let error = networkResult.firstError {
            throw error
        }

        var snapshot = current
        for response in orderedResponses {
            snapshot = append(response, to: snapshot)
        }
        snapshot.sections.sort { $0.date > $1.date }
        snapshot.historyCursor = contiguousResolvedCursor(
            from: oldestDate,
            targets: targets,
            responsesByDate: responsesByDate
        )
        await saveHomeFeed(snapshot)

        let source: ContentSource
        if networkResult.responses.isEmpty,
           let oldestCacheDate = cachedValues.values.map(\.cachedAt).min() {
            source = .cache(oldestCacheDate)
        } else {
            source = .network
        }
        return RepositoryValue(value: snapshot, source: source)
    }

    func fetchDetail(id: Int) async throws -> RepositoryValue<ArticleDetail> {
        if let cached = await cacheStore.loadDetail(id: id) {
            return RepositoryValue(value: cached.value, source: .cache(cached.cachedAt))
        }

        let detail = try await service.fetchDetail(id: id)
        await cacheStore.saveDetail(detail)
        return RepositoryValue(value: detail, source: .network)
    }

    func fetchStoryMetrics(id: Int) async throws -> DailyStoryMetrics {
        try await service.fetchStoryMetrics(id: id)
    }

    func fetchAnswerMetrics(answerID: Int) async throws -> OriginalAnswerMetrics {
        try await service.fetchAnswerMetrics(answerID: answerID)
    }

    func fetchHotList(forceRefresh: Bool) async throws -> RepositoryValue<HotListResponse> {
        if !forceRefresh,
           let cached = await cacheStore.loadHotList(),
           calendar.isDate(cached.cachedAt, inSameDayAs: now()) {
            return RepositoryValue(value: cached.value, source: .cache(cached.cachedAt))
        }

        do {
            let response = try await service.fetchHotList()
            await cacheStore.saveHotList(response)
            return RepositoryValue(value: response, source: .network)
        } catch {
            if let cached = await cacheStore.loadHotList() {
                return RepositoryValue(value: cached.value, source: .cache(cached.cachedAt))
            }
            throw error
        }
    }

    func fetchAnswers(questionID: Int) async throws -> AnswersResponse {
        try await service.fetchAnswers(questionID: questionID)
    }

    private func streamHomeFeed(
        to continuation: AsyncThrowingStream<HomeFeedEvent, Error>.Continuation
    ) async {
        let cachedHome = await cacheStore.loadHomeFeed()
        var current = cachedHome.map { snapshot(from: $0.value) } ?? HomeFeedSnapshot(sections: [], topStories: [])

        if let cachedHome {
            continuation.yield(.cached(RepositoryValue(
                value: current,
                source: .cache(cachedHome.cachedAt)
            )))
        } else if let latest = await cacheStore.loadLatest() {
            current = snapshot(from: latest.value)
            await saveHomeFeed(current)
            continuation.yield(.cached(RepositoryValue(
                value: current,
                source: .cache(latest.cachedAt)
            )))
        }

        do {
            let latest = try await service.fetchLatest()
            await cacheStore.saveLatest(latest)
            let refreshed = merge(latest: latest, into: current)
            await saveHomeFeed(refreshed)
            continuation.yield(.refreshed(RepositoryValue(value: refreshed, source: .network)))
            continuation.finish()
        } catch {
            if cachedHome == nil, current.sections.isEmpty, current.topStories.isEmpty {
                continuation.finish(throwing: error)
            } else {
                continuation.finish()
            }
        }
    }

    private func snapshot(from cached: CachedHomeFeed) -> HomeFeedSnapshot {
        HomeFeedSnapshot(
            sections: cached.sections,
            topStories: cached.topStories,
            historyCursor: cached.historyCursor
        )
    }

    private func snapshot(from response: DailyResponse) -> HomeFeedSnapshot {
        HomeFeedSnapshot(
            sections: makeSections(from: response),
            topStories: response.topStories
        )
    }

    private func merge(
        latest: DailyResponse,
        into current: HomeFeedSnapshot
    ) -> HomeFeedSnapshot {
        guard !current.sections.isEmpty else {
            return snapshot(from: latest)
        }

        let existingIDs = Set(current.sections.flatMap(\.stories).map(\.id))
        let stories = latest.stories.filter { !$0.title.isEmpty && !existingIDs.contains($0.id) }
        var sections = current.sections

        if let index = sections.firstIndex(where: { $0.date == latest.date }) {
            sections[index].stories.insert(contentsOf: stories, at: 0)
        } else if !stories.isEmpty {
            sections.insert(DailySection(date: latest.date, stories: stories), at: 0)
        }

        return HomeFeedSnapshot(
            sections: sections,
            topStories: latest.topStories,
            historyCursor: current.historyCursor ?? sections.last?.date
        )
    }

    private func append(
        _ response: DailyResponse,
        to current: HomeFeedSnapshot
    ) -> HomeFeedSnapshot {
        let existingIDs = Set(current.sections.flatMap(\.stories).map(\.id))
        let stories = response.stories.filter { !$0.title.isEmpty && !existingIDs.contains($0.id) }
        guard !stories.isEmpty else { return current }

        var sections = current.sections
        if let index = sections.firstIndex(where: { $0.date == response.date }) {
            sections[index].stories.append(contentsOf: stories)
        } else {
            sections.append(DailySection(date: response.date, stories: stories))
        }
        return HomeFeedSnapshot(
            sections: sections,
            topStories: current.topStories,
            historyCursor: current.historyCursor
        )
    }

    private func makeSections(from response: DailyResponse) -> [DailySection] {
        let stories = response.stories.filter { !$0.title.isEmpty }
        return stories.isEmpty ? [] : [DailySection(date: response.date, stories: stories)]
    }

    private func saveHomeFeed(_ snapshot: HomeFeedSnapshot) async {
        await cacheStore.saveHomeFeed(
            sections: snapshot.sections,
            topStories: snapshot.topStories,
            historyCursor: snapshot.historyCursor
        )
    }

    private func historicalTargets(
        before dateString: String,
        count: Int
    ) -> [HistoricalTarget] {
        guard count > 0, let date = Self.businessDateFormatter.date(from: dateString) else {
            return []
        }
        return (0..<count).compactMap { offset in
            guard let requestDate = Self.businessCalendar.date(
                byAdding: .day,
                value: -offset,
                to: date
            ), let responseDate = Self.businessCalendar.date(
                byAdding: .day,
                value: -1,
                to: requestDate
            ) else {
                return nil
            }
            return HistoricalTarget(
                requestDate: Self.businessDateFormatter.string(from: requestDate),
                responseDate: Self.businessDateFormatter.string(from: responseDate)
            )
        }
    }

    private func contiguousResolvedCursor(
        from oldestDate: String,
        targets: [HistoricalTarget],
        responsesByDate: [String: DailyResponse]
    ) -> String {
        var cursor = oldestDate
        for target in targets {
            guard responsesByDate[target.responseDate] != nil else { break }
            cursor = target.responseDate
        }
        return cursor
    }

    private func fetchHistoricalResponses(
        for targets: [HistoricalTarget]
    ) async -> HistoricalNetworkResult {
        guard !targets.isEmpty else {
            return HistoricalNetworkResult(responses: [], firstError: nil)
        }

        let service = self.service
        return await withTaskGroup(of: HistoricalFetchOutcome.self) { group in
            for target in targets {
                group.addTask {
                    do {
                        let response = try await service.fetchBefore(date: target.requestDate)
                        return .success(HistoricalResponse(target: target, response: response))
                    } catch {
                        return .failure(error)
                    }
                }
            }

            var responses: [HistoricalResponse] = []
            var firstError: Error?
            for await outcome in group {
                switch outcome {
                case .success(let response):
                    responses.append(response)
                case .failure(let error):
                    firstError = firstError ?? error
                }
            }
            return HistoricalNetworkResult(responses: responses, firstError: firstError)
        }
    }

    private static let businessCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private static var businessDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = businessCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }
}

private struct HistoricalTarget {
    let requestDate: String
    let responseDate: String
}

private struct HistoricalResponse {
    let target: HistoricalTarget
    let response: DailyResponse
}

private struct HistoricalNetworkResult {
    let responses: [HistoricalResponse]
    let firstError: Error?
}

private enum HistoricalFetchOutcome {
    case success(HistoricalResponse)
    case failure(Error)
}

private enum HistoryPaginationError: Error {
    case invalidCursor(String)
}
