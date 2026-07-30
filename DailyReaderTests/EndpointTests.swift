import XCTest
@testable import DailyReader

final class EndpointTests: XCTestCase {
    func testRelativeEndpointBuildsURLMethodHeadersAndBody() throws {
        let body = Data("{\"enabled\":true}".utf8)
        let endpoint = Endpoint<DailyResponse>(
            baseURL: URL(string: "https://example.com/api/4")!,
            path: "/news/latest/",
            method: .post,
            queryItems: [URLQueryItem(name: "page", value: "2")],
            headers: ["X-Client": "DailyReader"],
            body: body
        )

        let request = try endpoint.urlRequest(timeoutInterval: 12)

        XCTAssertEqual(request.url?.absoluteString, "https://example.com/api/4/news/latest?page=2")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Client"), "DailyReader")
        XCTAssertEqual(request.httpBody, body)
        XCTAssertEqual(request.timeoutInterval, 12)
    }

    func testAbsoluteEndpointPreservesExistingQueryAndAppendsItems() throws {
        let endpoint = Endpoint<AnswersResponse>(
            absoluteURL: URL(string: "https://api.zhihu.com/v4/questions/1/answers?offset=50")!,
            queryItems: [URLQueryItem(name: "limit", value: "50")]
        )

        let request = try endpoint.urlRequest(timeoutInterval: 15)
        let components = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)

        XCTAssertEqual(components?.path, "/v4/questions/1/answers")
        XCTAssertEqual(components?.queryItems, [
            URLQueryItem(name: "offset", value: "50"),
            URLQueryItem(name: "limit", value: "50")
        ])
    }

    func testZhihuEndpointFactoryBuildsExpectedURLs() throws {
        let latest = try ZhihuEndpoints.latest().urlRequest(timeoutInterval: 15)
        let before = try ZhihuEndpoints.before(date: "20260728").urlRequest(timeoutInterval: 15)
        let detail = try ZhihuEndpoints.detail(id: 42).urlRequest(timeoutInterval: 15)
        let storyMetrics = try ZhihuEndpoints.storyMetrics(id: 42).urlRequest(timeoutInterval: 15)
        let answerMetrics = try ZhihuEndpoints.answerMetrics(answerID: 456).urlRequest(timeoutInterval: 15)
        let hotList = try ZhihuEndpoints.hotList().urlRequest(timeoutInterval: 15)
        let answers = try ZhihuEndpoints.answers(questionID: 123).urlRequest(timeoutInterval: 15)

        XCTAssertEqual(latest.url?.absoluteString, "https://daily.zhihu.com/api/4/news/latest")
        XCTAssertEqual(before.url?.absoluteString, "https://daily.zhihu.com/api/4/news/before/20260728")
        XCTAssertEqual(detail.url?.absoluteString, "https://daily.zhihu.com/api/4/news/42")
        XCTAssertEqual(storyMetrics.url?.absoluteString, "https://daily.zhihu.com/api/4/story-extra/42")
        XCTAssertEqual(storyMetrics.cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertEqual(
            answerMetrics.url?.absoluteString,
            "https://www.zhihu.com/api/v4/answers/456?include=voteup_count,comment_count,favlists_count"
        )
        XCTAssertEqual(answerMetrics.cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertEqual(hotList.url?.absoluteString, "https://api.zhihu.com/topstory/hot-list?limit=50")
        XCTAssertEqual(answers.url?.absoluteString, "https://api.zhihu.com/v4/questions/123/answers?limit=50&offset=0&sort_by=default")
    }
}
