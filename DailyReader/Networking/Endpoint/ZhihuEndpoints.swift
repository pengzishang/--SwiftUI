import Foundation

enum ZhihuEndpoints {
    private static let dailyBaseURL = URL(string: "https://daily.zhihu.com/api/4")!
    private static let zhihuAPIBaseURL = URL(string: "https://api.zhihu.com")!
    private static let zhihuWebAPIBaseURL = URL(string: "https://www.zhihu.com/api/v4")!

    static func latest() -> Endpoint<DailyResponse> {
        Endpoint(baseURL: dailyBaseURL, path: "news/latest")
    }

    static func before(date: String) -> Endpoint<DailyResponse> {
        Endpoint(baseURL: dailyBaseURL, path: "news/before/\(date)")
    }

    static func detail(id: Int) -> Endpoint<ArticleDetail> {
        Endpoint(baseURL: dailyBaseURL, path: "news/\(id)")
    }

    static func storyMetrics(id: Int) -> Endpoint<DailyStoryMetrics> {
        Endpoint(
            baseURL: dailyBaseURL,
            path: "story-extra/\(id)",
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }

    static func answerMetrics(answerID: Int) -> Endpoint<OriginalAnswerMetrics> {
        Endpoint(
            baseURL: zhihuWebAPIBaseURL,
            path: "answers/\(answerID)",
            queryItems: [
                URLQueryItem(
                    name: "include",
                    value: "voteup_count,comment_count,favlists_count"
                )
            ],
            cachePolicy: .reloadIgnoringLocalCacheData
        )
    }

    static func hotList(limit: Int = 50) -> Endpoint<ZhihuHotListResponse> {
        Endpoint(
            baseURL: zhihuAPIBaseURL,
            path: "topstory/hot-list",
            queryItems: [URLQueryItem(name: "limit", value: String(limit))]
        )
    }

    static func answers(
        questionID: Int,
        limit: Int = 50,
        offset: Int = 0,
        sortBy: String = "default"
    ) -> Endpoint<AnswersResponse> {
        Endpoint(
            baseURL: zhihuAPIBaseURL,
            path: "v4/questions/\(questionID)/answers",
            queryItems: [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset)),
                URLQueryItem(name: "sort_by", value: sortBy)
            ]
        )
    }

    static func answers(nextURL: URL) -> Endpoint<AnswersResponse> {
        Endpoint(absoluteURL: nextURL)
    }
}
