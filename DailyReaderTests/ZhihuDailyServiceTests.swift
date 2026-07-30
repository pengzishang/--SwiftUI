import XCTest
@testable import DailyReader

final class ZhihuDailyServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchLatestParsesStoriesAndTopStories() async throws {
        let service = makeService(json: "latest_success")

        let response = try await service.fetchLatest()

        XCTAssertEqual(response.date, "20260621")
        XCTAssertEqual(response.stories.map(\.id), [1, 2])
        XCTAssertEqual(response.topStories.first?.title, "顶部故事")
    }

    func testFetchBeforeUsesBeforePathAndUserAgent() async throws {
        var capturedRequest: URLRequest?
        let service = makeService(statusCode: 200, data: fixtureData("latest_success")) { request in
            capturedRequest = request
        }

        _ = try await service.fetchBefore(date: "20260621")

        XCTAssertEqual(capturedRequest?.url?.path, "/api/4/news/before/20260621")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "User-Agent"), HTTPClient.browserUserAgent)
    }

    func testDefaultClientUsesReachableDailyHost() async throws {
        var capturedRequest: URLRequest?
        let service = makeService(statusCode: 200, data: fixtureData("latest_success")) { request in
            capturedRequest = request
        }

        _ = try await service.fetchLatest()

        XCTAssertEqual(capturedRequest?.url?.host, "daily.zhihu.com")
    }

    func testFetchLatestSkipsBrokenStoryInsteadOfFailingWholeResponse() async throws {
        let service = makeService(json: "latest_with_broken_story")

        let response = try await service.fetchLatest()

        XCTAssertEqual(response.stories.map(\.id), [1])
    }

    func testFetchDetailParsesShareURL() async throws {
        let service = makeService(json: "detail_success")

        let detail = try await service.fetchDetail(id: 1)

        XCTAssertEqual(detail.id, 1)
        XCTAssertEqual(detail.shareURL, "https://example.com/1")
        XCTAssertEqual(detail.url, "https://daily.example.com/1")
        XCTAssertEqual(detail.images, ["https://example.com/image.jpg"])
    }

    func testFetchStoryMetricsUsesStoryExtraAndDecodesFlexibleValues() async throws {
        var capturedRequest: URLRequest?
        let data = Data("{\"popularity\":\"30\",\"comments\":10,\"long_comments\":4,\"short_comments\":6}".utf8)
        let service = makeService(statusCode: 200, data: data) { request in
            capturedRequest = request
        }

        let metrics = try await service.fetchStoryMetrics(id: 42)

        XCTAssertEqual(capturedRequest?.url?.absoluteString, "https://daily.zhihu.com/api/4/story-extra/42")
        XCTAssertEqual(capturedRequest?.cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertEqual(metrics, DailyStoryMetrics(popularity: 30, comments: 10, longComments: 4, shortComments: 6))
    }

    func testFetchAnswerMetricsUsesWebAPIAndDecodesVisibleFields() async throws {
        var capturedRequest: URLRequest?
        let data = Data("{\"id\":456,\"voteup_count\":1848,\"comment_count\":179,\"favlists_count\":1050}".utf8)
        let service = makeService(statusCode: 200, data: data) { request in
            capturedRequest = request
        }

        let metrics = try await service.fetchAnswerMetrics(answerID: 456)

        XCTAssertEqual(
            capturedRequest?.url?.absoluteString,
            "https://www.zhihu.com/api/v4/answers/456?include=voteup_count,comment_count,favlists_count"
        )
        XCTAssertEqual(capturedRequest?.cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertEqual(metrics, OriginalAnswerMetrics(id: 456, voteupCount: 1_848, commentCount: 179, favoriteListCount: 1_050))
    }

    func testFetchHotListUsesZhihuTopstoryHotListWithThirtyItems() async throws {
        var capturedRequests: [URLRequest] = []
        let service = makeService(
            responses: [
                hotListJSON(ids: 1...30)
            ],
            capture: { capturedRequests.append($0) }
        )

        let response = try await service.fetchHotList()

        XCTAssertEqual(capturedRequests.map { $0.url?.absoluteString }, [
            "https://api.zhihu.com/topstory/hot-list?limit=50"
        ])
        XCTAssertGreaterThanOrEqual(response.data.count, 30)
        XCTAssertEqual(response.data.map(\.id), Array(1...response.data.count))
        XCTAssertEqual(response.data.first?.target.id, 1_000_001)
        XCTAssertEqual(response.data.first?.target.title, "知乎热榜问题 1")
        XCTAssertEqual(response.data.first?.target.thumbnail, "https://example.com/answer/1.jpg")
        XCTAssertEqual(response.data.first?.target.answerCount, 201)
        XCTAssertNil(response.data.first?.target.url)
        XCTAssertEqual(response.data.first?.detailText, "999 万热度")
        XCTAssertEqual(response.data.last?.target.id, 1_000_030)
    }

    func testFetchAnswersUsesZhihuQuestionAnswersAPIAndFollowsPaging() async throws {
        var allRequests: [URLRequest] = []
        var capturedRequests: [URLRequest] = []
        let firstPage = answersJSON(ids: 1...2, isEnd: false, next: "https://api.zhihu.com/v4/questions/123/answers?limit=50&offset=50&sort_by=default")
        let secondPage = answersJSON(ids: 3...3, isEnd: true, next: nil)
        XCTAssertNoThrow(try JSONDecoder().decode(AnswersResponse.self, from: firstPage))
        XCTAssertNoThrow(try JSONDecoder().decode(AnswersResponse.self, from: secondPage))
        let service = makeService { request in
            allRequests.append(request)
            let absoluteString = request.url?.absoluteString ?? ""
            guard absoluteString.contains("/v4/questions/123/answers") else {
                return MockURLProtocol.Response(statusCode: 200, data: self.fixtureData("latest_success"))
            }

            capturedRequests.append(request)
            if absoluteString.contains("offset=50") {
                return MockURLProtocol.Response(statusCode: 200, data: secondPage)
            }
            return MockURLProtocol.Response(statusCode: 200, data: firstPage)
        }

        let response: AnswersResponse
        do {
            response = try await service.fetchAnswers(questionID: 123)
        } catch {
            XCTFail("Fetch answers failed with \(error); requests: \(allRequests.map { $0.url?.absoluteString ?? "<nil>" })")
            throw error
        }

        XCTAssertEqual(capturedRequests.map { $0.url?.absoluteString }, [
            "https://api.zhihu.com/v4/questions/123/answers?limit=50&offset=0&sort_by=default",
            "https://api.zhihu.com/v4/questions/123/answers?limit=50&offset=50&sort_by=default"
        ])
        XCTAssertEqual(response.data.map(\.id), [1, 2, 3])
        XCTAssertEqual(response.data.first?.author.name, "回答作者 1")
        XCTAssertEqual(response.data.first?.excerpt, "这是第 1 个回答摘要")
        XCTAssertEqual(response.data.first?.voteupCount, 101)
    }

    func testNon2xxThrowsHTTPStatus() async {
        let service = makeService(statusCode: 502, data: Data("{}".utf8))

        do {
            _ = try await service.fetchLatest()
            XCTFail("Expected http status error")
        } catch let error as APIError {
            XCTAssertEqual(error, .httpStatus(502))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testBoundaryHTTPStatusesThrowHTTPStatus() async {
        for statusCode in [403, 404, 500] {
            let service = makeService(statusCode: statusCode, data: Data("{}".utf8))

            do {
                _ = try await service.fetchLatest()
                XCTFail("Expected http status error for \(statusCode)")
            } catch let error as APIError {
                XCTAssertEqual(error, .httpStatus(statusCode))
            } catch {
                XCTFail("Unexpected error for \(statusCode): \(error)")
            }
        }
    }

    func testTimeoutThrowsTransportError() async {
        let service = makeService(error: URLError(.timedOut))

        do {
            _ = try await service.fetchLatest()
            XCTFail("Expected timeout transport error")
        } catch let error as APIError {
            if case .transport(let message) = error {
                XCTAssertFalse(message.isEmpty)
            } else {
                XCTFail("Expected transport error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMalformedJSONThrowsDecodeError() async {
        let service = makeService(statusCode: 200, data: Data("{ broken".utf8))

        do {
            _ = try await service.fetchLatest()
            XCTFail("Expected decoding error")
        } catch let error as APIError {
            XCTAssertEqual(error, .decodingFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testEmptyResponseThrowsInvalidResponse() async {
        let service = makeService(statusCode: 200, data: Data())

        do {
            _ = try await service.fetchLatest()
            XCTFail("Expected invalidResponse or decodingFailed error")
        } catch let error as APIError {
            XCTAssertTrue(error == .decodingFailed || error == .invalidResponse)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testNetworkConnectionLostThrowsTransportError() async {
        let service = makeService(error: URLError(.networkConnectionLost))

        do {
            _ = try await service.fetchLatest()
            XCTFail("Expected transport error")
        } catch let error as APIError {
            if case .transport(let message) = error {
                XCTAssertFalse(message.isEmpty)
            } else {
                XCTFail("Expected transport error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testNotConnectedToInternetThrowsTransportError() async {
        let service = makeService(error: URLError(.notConnectedToInternet))

        do {
            _ = try await service.fetchLatest()
            XCTFail("Expected transport error")
        } catch let error as APIError {
            if case .transport(let message) = error {
                XCTAssertFalse(message.isEmpty)
            } else {
                XCTFail("Expected transport error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUserAgentMatchesBrowserFormat() {
        let userAgent = HTTPClient.browserUserAgent
        XCTAssertTrue(userAgent.contains("Mozilla/5.0"))
        XCTAssertTrue(userAgent.contains("AppleWebKit"))
        XCTAssertTrue(userAgent.contains("Safari"))
        XCTAssertTrue(userAgent.contains("Mobile"))
    }

    func testHighConcurrencyRequestThreadSafety() async throws {
        let service = makeService(json: "latest_success")
        
        try await withThrowingTaskGroup(of: DailyResponse.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    try await service.fetchLatest()
                }
            }
            
            var count = 0
            while let response = try await group.next() {
                XCTAssertEqual(response.date, "20260621")
                count += 1
            }
            XCTAssertEqual(count, 100)
        }
    }

    private func makeService(json name: String) -> ZhihuDailyService {
        makeService(statusCode: 200, data: fixtureData(name))
    }

    private func makeService(statusCode: Int, data: Data) -> ZhihuDailyService {
        makeService(statusCode: statusCode, data: data, capture: nil)
    }

    private func makeService(statusCode: Int, data: Data, capture: ((URLRequest) -> Void)?) -> ZhihuDailyService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = { request in
            capture?(request)
            return MockURLProtocol.Response(statusCode: statusCode, data: data)
        }
        let session = URLSession(configuration: configuration)
        let httpClient = HTTPClient(session: session)
        return ZhihuDailyService(httpClient: httpClient)
    }

    private func makeService(responses: [Data], capture: ((URLRequest) -> Void)? = nil) -> ZhihuDailyService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        var remainingResponses = responses
        MockURLProtocol.handler = { request in
            capture?(request)
            guard !remainingResponses.isEmpty else {
                return MockURLProtocol.Response(statusCode: 500, data: Data("{}".utf8))
            }
            return MockURLProtocol.Response(statusCode: 200, data: remainingResponses.removeFirst())
        }
        let session = URLSession(configuration: configuration)
        let httpClient = HTTPClient(session: session)
        return ZhihuDailyService(httpClient: httpClient)
    }

    private func makeService(handler: @escaping (URLRequest) throws -> MockURLProtocol.Response) -> ZhihuDailyService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = handler
        let session = URLSession(configuration: configuration)
        let httpClient = HTTPClient(session: session)
        return ZhihuDailyService(httpClient: httpClient)
    }

    private func makeService(error: Error) -> ZhihuDailyService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = { _ in
            throw error
        }
        let session = URLSession(configuration: configuration)
        let httpClient = HTTPClient(session: session)
        return ZhihuDailyService(httpClient: httpClient)
    }

    private func fixtureData(_ name: String) -> Data {
        let url = Bundle(for: Self.self).url(forResource: name, withExtension: "json")!
        return try! Data(contentsOf: url)
    }

    private func hotListJSON(ids: ClosedRange<Int>) -> Data {
        let items = ids.map { id in
            """
            {
              "type": "hot_list_feed",
              "id": "\(id)_1782626896.304462",
              "target": {
                "id": \(1_000_000 + id),
                "title": "知乎热榜问题 \(id)",
                "url": "https://api.zhihu.com/questions/\(1_000_000 + id)",
                "type": "question",
                "excerpt": "这是第 \(id) 个知乎热榜问题的摘要",
                "answer_count": \(200 + id)
              },
              "detail_text": "\(1000 - id) 万热度",
              "children": [
                {
                  "type": "answer",
                  "thumbnail": "https://example.com/answer/\(id).jpg"
                }
              ]
            }
            """
        }
        let json = #"{"data":["# + items.joined(separator: ",") + #"]}"#
        return Data(json.utf8)
    }

    private func dailyJSON(date: String, ids: ClosedRange<Int>) -> Data {
        let stories = ids.map { id in
            """
            {
              "id": \(id),
              "title": "日报 \(id)",
              "images": ["https://example.com/daily/\(id).jpg"],
              "hint": "作者 \(id)",
              "url": "https://daily.zhihu.com/story/\(id)"
            }
            """
        }
        let json = #"{"date": ""# + date + #"", "stories": ["# + stories.joined(separator: ",") + #"], "top_stories": []}"#
        return Data(json.utf8)
    }

    private func answersJSON(ids: ClosedRange<Int>, isEnd: Bool, next: String?) -> Data {
        let answers = ids.map { id in
            """
            {
              "id": \(id),
              "author": {
                "name": "回答作者 \(id)",
                "avatar_url": "https://example.com/avatar/\(id).jpg"
              },
              "content": "<p>这是第 \(id) 个回答正文</p>",
              "excerpt": "这是第 \(id) 个回答摘要",
              "voteup_count": \(100 + id)
            }
            """
        }
        let nextJSON = next.map { "\"" + $0 + "\"" } ?? "null"
        let json = #"{"data": ["# + answers.joined(separator: ",") + #"], "paging": {"is_end": "# + String(isEnd) + #", "next": "# + nextJSON + #"}}"#
        return Data(json.utf8)
    }
}
