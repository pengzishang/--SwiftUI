import Foundation

protocol HomeRepositoryProtocol {
    func loadHomeFeed() -> AsyncThrowingStream<HomeFeedEvent, Error>
    func refreshHomeFeed(current: HomeFeedSnapshot) async throws -> RepositoryValue<HomeFeedSnapshot>
    func loadMore(before oldestDate: String, current: HomeFeedSnapshot) async throws -> RepositoryValue<HomeFeedSnapshot>
}

protocol ArticleRepositoryProtocol {
    func fetchDetail(id: Int) async throws -> RepositoryValue<ArticleDetail>
}

protocol ArticleMetricsRepositoryProtocol {
    func fetchStoryMetrics(id: Int) async throws -> DailyStoryMetrics
    func fetchAnswerMetrics(answerID: Int) async throws -> OriginalAnswerMetrics
}

protocol HotListRepositoryProtocol {
    func fetchHotList(forceRefresh: Bool) async throws -> RepositoryValue<HotListResponse>
}

protocol AnswersRepositoryProtocol {
    func fetchAnswers(questionID: Int) async throws -> AnswersResponse
}

protocol DailyRepositoryProtocol:
    HomeRepositoryProtocol,
    ArticleRepositoryProtocol,
    ArticleMetricsRepositoryProtocol,
    HotListRepositoryProtocol,
    AnswersRepositoryProtocol {}
