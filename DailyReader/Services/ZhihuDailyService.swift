import Foundation

final class ZhihuDailyService: DailyServiceProtocol {
    private static let maxAnswerPages = 20
    private let httpClient: HTTPClientProtocol

    init(httpClient: HTTPClientProtocol = HTTPClient()) {
        self.httpClient = httpClient
    }

    func fetchLatest() async throws -> DailyResponse {
        try await httpClient.execute(ZhihuEndpoints.latest())
    }

    func fetchBefore(date: String) async throws -> DailyResponse {
        try await httpClient.execute(ZhihuEndpoints.before(date: date))
    }

    func fetchDetail(id: Int) async throws -> ArticleDetail {
        try await httpClient.execute(ZhihuEndpoints.detail(id: id))
    }

    func fetchStoryMetrics(id: Int) async throws -> DailyStoryMetrics {
        try await httpClient.execute(ZhihuEndpoints.storyMetrics(id: id))
    }

    func fetchAnswerMetrics(answerID: Int) async throws -> OriginalAnswerMetrics {
        try await httpClient.execute(ZhihuEndpoints.answerMetrics(answerID: answerID))
    }

    func fetchHotList() async throws -> HotListResponse {
        let response: ZhihuHotListResponse = try await httpClient.execute(ZhihuEndpoints.hotList())
        return HotListResponse(zhihuHotListResponse: response)
    }

    func fetchAnswers(questionID: Int) async throws -> AnswersResponse {
        var endpoint = ZhihuEndpoints.answers(questionID: questionID)
        var visitedURLs = Set<String>()
        var answers: [AnswerItem] = []
        var seenAnswerIDs = Set<Int>()

        for _ in 0..<Self.maxAnswerPages {
            let request = try endpoint.urlRequest(timeoutInterval: 15)
            guard let url = request.url, visitedURLs.insert(url.absoluteString).inserted else {
                break
            }

            let response: AnswersResponse = try await httpClient.execute(endpoint)
            for answer in response.data where seenAnswerIDs.insert(answer.id).inserted {
                answers.append(answer)
            }

            guard response.paging?.isEnd == false,
                  let nextURLString = response.paging?.next,
                  let nextURL = URL(string: nextURLString)
            else {
                break
            }
            endpoint = ZhihuEndpoints.answers(nextURL: nextURL)
        }

        return AnswersResponse(data: answers)
    }
}
