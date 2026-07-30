import Foundation
@testable import DailyReader

final class RepositoryMockDailyService: DailyServiceProtocol {
    var latestResult: Result<DailyResponse, Error> = .success(.fixture)
    var beforeResult: Result<DailyResponse, Error> = .success(.historyFixture)
    var beforeResults: [String: Result<DailyResponse, Error>] = [:]
    var beforeDelayNanoseconds: UInt64 = 0
    var detailResult: Result<ArticleDetail, Error> = .success(.fixture)
    var storyMetricsResult: Result<DailyStoryMetrics, Error> = .success(.fixture)
    var answerMetricsResult: Result<OriginalAnswerMetrics, Error> = .success(.fixture)
    var hotListResult: Result<HotListResponse, Error> = .success(.fixture)
    var answersResult: Result<AnswersResponse, Error> = .success(AnswersResponse(data: []))

    private let lock = NSLock()
    private var _latestCallCount = 0
    private var _requestedBeforeDates: [String] = []
    private var _activeBeforeCallCount = 0
    private var _maximumConcurrentBeforeCallCount = 0
    private var _detailCallCount = 0
    private var _storyMetricsCallCount = 0
    private var _answerMetricsCallCount = 0
    private var _hotListCallCount = 0
    private var _answersCallCount = 0

    var latestCallCount: Int { lock.withLock { _latestCallCount } }
    var beforeCallCount: Int { lock.withLock { _requestedBeforeDates.count } }
    var requestedBeforeDates: [String] { lock.withLock { _requestedBeforeDates } }
    var maximumConcurrentBeforeCallCount: Int { lock.withLock { _maximumConcurrentBeforeCallCount } }
    var detailCallCount: Int { lock.withLock { _detailCallCount } }
    var storyMetricsCallCount: Int { lock.withLock { _storyMetricsCallCount } }
    var answerMetricsCallCount: Int { lock.withLock { _answerMetricsCallCount } }
    var hotListCallCount: Int { lock.withLock { _hotListCallCount } }
    var answersCallCount: Int { lock.withLock { _answersCallCount } }

    func fetchLatest() async throws -> DailyResponse {
        lock.withLock { _latestCallCount += 1 }
        return try latestResult.get()
    }

    func fetchBefore(date: String) async throws -> DailyResponse {
        lock.withLock {
            _requestedBeforeDates.append(date)
            _activeBeforeCallCount += 1
            _maximumConcurrentBeforeCallCount = max(
                _maximumConcurrentBeforeCallCount,
                _activeBeforeCallCount
            )
        }
        defer { lock.withLock { _activeBeforeCallCount -= 1 } }

        if beforeDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: beforeDelayNanoseconds)
        }
        return try (beforeResults[date] ?? beforeResult).get()
    }

    func fetchDetail(id: Int) async throws -> ArticleDetail {
        lock.withLock { _detailCallCount += 1 }
        return try detailResult.get()
    }

    func fetchStoryMetrics(id: Int) async throws -> DailyStoryMetrics {
        lock.withLock { _storyMetricsCallCount += 1 }
        return try storyMetricsResult.get()
    }

    func fetchAnswerMetrics(answerID: Int) async throws -> OriginalAnswerMetrics {
        lock.withLock { _answerMetricsCallCount += 1 }
        return try answerMetricsResult.get()
    }

    func fetchHotList() async throws -> HotListResponse {
        lock.withLock { _hotListCallCount += 1 }
        return try hotListResult.get()
    }

    func fetchAnswers(questionID: Int) async throws -> AnswersResponse {
        lock.withLock { _answersCallCount += 1 }
        return try answersResult.get()
    }
}

actor RepositoryInMemoryCacheStore: CacheStore {
    var latest: CachedValue<DailyResponse>?
    var daily: [String: CachedValue<DailyResponse>] = [:]
    var details: [Int: CachedValue<ArticleDetail>] = [:]
    var home: CachedValue<CachedHomeFeed>?
    var hotList: CachedValue<HotListResponse>?

    init(
        latest: CachedValue<DailyResponse>? = nil,
        daily: [String: CachedValue<DailyResponse>] = [:],
        details: [Int: CachedValue<ArticleDetail>] = [:],
        home: CachedValue<CachedHomeFeed>? = nil,
        hotList: CachedValue<HotListResponse>? = nil
    ) {
        self.latest = latest
        self.daily = daily
        self.details = details
        self.home = home
        self.hotList = hotList
    }

    func saveLatest(_ response: DailyResponse) async {
        latest = CachedValue(value: response, cachedAt: Date())
    }

    func loadLatest() async -> CachedValue<DailyResponse>? { latest }

    func saveDaily(_ response: DailyResponse) async {
        daily[response.date] = CachedValue(value: response, cachedAt: Date())
    }

    func loadDaily(date: String) async -> CachedValue<DailyResponse>? { daily[date] }

    func loadDaily(dates: [String]) async -> [String: CachedValue<DailyResponse>] {
        Dictionary(uniqueKeysWithValues: dates.compactMap { date in
            daily[date].map { (date, $0) }
        })
    }

    func saveDetail(_ detail: ArticleDetail) async {
        details[detail.id] = CachedValue(value: detail, cachedAt: Date())
    }

    func loadDetail(id: Int) async -> CachedValue<ArticleDetail>? { details[id] }

    func saveHomeFeed(
        sections: [DailySection],
        topStories: [TopStory],
        historyCursor: String?
    ) async {
        home = CachedValue(
            value: CachedHomeFeed(
                sections: sections,
                topStories: topStories,
                historyCursor: historyCursor
            ),
            cachedAt: Date()
        )
    }

    func loadHomeFeed() async -> CachedValue<CachedHomeFeed>? { home }

    func saveHotList(_ response: HotListResponse) async {
        hotList = CachedValue(value: response, cachedAt: Date())
    }

    func loadHotList() async -> CachedValue<HotListResponse>? { hotList }
}
