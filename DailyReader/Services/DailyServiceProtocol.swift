protocol DailyNewsServiceProtocol {
    func fetchLatest() async throws -> DailyResponse
    func fetchBefore(date: String) async throws -> DailyResponse
    func fetchDetail(id: Int) async throws -> ArticleDetail
}

protocol ArticleMetricsServiceProtocol {
    func fetchStoryMetrics(id: Int) async throws -> DailyStoryMetrics
    func fetchAnswerMetrics(answerID: Int) async throws -> OriginalAnswerMetrics
}

protocol HotListServiceProtocol {
    func fetchHotList() async throws -> HotListResponse
    func fetchAnswers(questionID: Int) async throws -> AnswersResponse
}

protocol DailyServiceProtocol:
    DailyNewsServiceProtocol,
    ArticleMetricsServiceProtocol,
    HotListServiceProtocol {}
