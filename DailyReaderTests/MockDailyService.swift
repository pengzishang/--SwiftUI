import Foundation
@testable import DailyReader

final class MockDailyService: DailyServiceProtocol {
    var latestResult: Result<DailyResponse, Error> = .success(.fixture)
    var beforeResult: Result<DailyResponse, Error> = .success(.historyFixture)
    var beforeResults: [String: Result<DailyResponse, Error>] = [:]
    var beforeDelayNanoseconds: UInt64 = 0
    var detailResult: Result<ArticleDetail, Error> = .success(.fixture)
    var storyMetricsResult: Result<DailyStoryMetrics, Error> = .success(.fixture)
    var answerMetricsResult: Result<OriginalAnswerMetrics, Error> = .success(.fixture)
    var hotListResult: Result<HotListResponse, Error> = .success(.fixture)

    private let lock = NSLock()
    private var _latestCallCount = 0
    private var _beforeCallCount = 0
    private var _detailCallCount = 0
    private var _storyMetricsCallCount = 0
    private var _answerMetricsCallCount = 0
    private var _hotListCallCount = 0

    var latestCallCount: Int { lock.withLock { _latestCallCount } }
    var beforeCallCount: Int { lock.withLock { _beforeCallCount } }
    var detailCallCount: Int { lock.withLock { _detailCallCount } }
    var storyMetricsCallCount: Int { lock.withLock { _storyMetricsCallCount } }
    var answerMetricsCallCount: Int { lock.withLock { _answerMetricsCallCount } }
    var hotListCallCount: Int { lock.withLock { _hotListCallCount } }

    func fetchLatest() async throws -> DailyResponse {
        lock.withLock { _latestCallCount += 1 }
        return try latestResult.get()
    }

    func fetchBefore(date: String) async throws -> DailyResponse {
        lock.withLock { _beforeCallCount += 1 }
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
        AnswersResponse(data: [])
    }
}

func makeRepository(
    service: DailyServiceProtocol,
    cacheStore: CacheStore,
    calendar: Calendar = .current,
    now: @escaping @Sendable () -> Date = { Date() }
) -> DailyRepository {
    DailyRepository(
        service: service,
        cacheStore: cacheStore,
        calendar: calendar,
        now: now
    )
}

extension DailyResponse {
    static let fixture = DailyResponse(
        date: "20260621",
        stories: [
            StorySummary(id: 1, title: "第一篇日报", hint: "测试", url: "https://example.com/1"),
            StorySummary(id: 2, title: "第二篇日报", hint: "测试", url: "https://example.com/2")
        ],
        topStories: [
            TopStory(id: 1, title: "顶部故事", image: nil, url: "https://example.com/1")
        ]
    )

    static let historyFixture = DailyResponse(
        date: "20260620",
        stories: [
            StorySummary(id: 2, title: "重复文章会被去重"),
            StorySummary(id: 3, title: "历史日报")
        ]
    )
}

extension ArticleDetail {
    static let fixture = ArticleDetail(
        id: 1,
        title: "第一篇日报",
        body: "<p>正文</p>",
        shareURL: "https://example.com/1"
    )
}

extension DailyStoryMetrics {
    static let fixture = DailyStoryMetrics(popularity: 30, comments: 10)
}

extension OriginalAnswerMetrics {
    static let fixture = OriginalAnswerMetrics(
        id: 456,
        voteupCount: 1_848,
        commentCount: 179,
        favoriteListCount: 1_050
    )
}

extension HotListResponse {
    static let fixture = fixture()

    static func fixture(questionID: Int = 1001, title: String = "缓存热榜问题") -> HotListResponse {
        HotListResponse(data: [
            HotItem(
                id: 1,
                target: HotTarget(
                    id: questionID,
                    title: title,
                    excerpt: "用于验证热榜每日缓存",
                    thumbnail: nil
                ),
                detailText: "100 万热度"
            )
        ])
    }
}
