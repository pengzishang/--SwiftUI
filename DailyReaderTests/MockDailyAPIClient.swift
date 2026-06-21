import Foundation
@testable import DailyReader

final class MockDailyAPIClient: DailyAPIClient {
    var latestResult: Result<DailyResponse, Error> = .success(.fixture)
    var beforeResult: Result<DailyResponse, Error> = .success(.historyFixture)
    var detailResult: Result<ArticleDetail, Error> = .success(.fixture)

    private(set) var latestCallCount = 0
    private(set) var beforeCallCount = 0
    private(set) var detailCallCount = 0

    func fetchLatest() async throws -> DailyResponse {
        latestCallCount += 1
        return try latestResult.get()
    }

    func fetchBefore(date: String) async throws -> DailyResponse {
        beforeCallCount += 1
        return try beforeResult.get()
    }

    func fetchDetail(id: Int) async throws -> ArticleDetail {
        detailCallCount += 1
        return try detailResult.get()
    }
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
