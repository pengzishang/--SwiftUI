import XCTest
@testable import DailyReader

final class ZhihuDailyAPITests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchLatestParsesStoriesAndTopStories() async throws {
        let api = makeAPI(json: "latest_success")

        let response = try await api.fetchLatest()

        XCTAssertEqual(response.date, "20260621")
        XCTAssertEqual(response.stories.map(\.id), [1, 2])
        XCTAssertEqual(response.topStories.first?.title, "顶部故事")
    }

    func testFetchBeforeUsesBeforePathAndUserAgent() async throws {
        var capturedRequest: URLRequest?
        let api = makeAPI(statusCode: 200, data: fixtureData("latest_success")) { request in
            capturedRequest = request
        }

        _ = try await api.fetchBefore(date: "20260621")

        XCTAssertEqual(capturedRequest?.url?.path, "/api/4/news/before/20260621")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "User-Agent"), "DailyReaderSwiftUI/1.0")
    }

    func testFetchLatestSkipsBrokenStoryInsteadOfFailingWholeResponse() async throws {
        let api = makeAPI(json: "latest_with_broken_story")

        let response = try await api.fetchLatest()

        XCTAssertEqual(response.stories.map(\.id), [1])
    }

    func testFetchDetailParsesShareURL() async throws {
        let api = makeAPI(json: "detail_success")

        let detail = try await api.fetchDetail(id: 1)

        XCTAssertEqual(detail.id, 1)
        XCTAssertEqual(detail.shareURL, "https://example.com/1")
        XCTAssertEqual(detail.url, "https://daily.example.com/1")
        XCTAssertEqual(detail.images, ["https://example.com/image.jpg"])
    }

    func testNon2xxThrowsHTTPStatus() async {
        let api = makeAPI(statusCode: 502, data: Data("{}".utf8))

        do {
            _ = try await api.fetchLatest()
            XCTFail("Expected http status error")
        } catch let error as APIError {
            XCTAssertEqual(error, .httpStatus(502))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testBoundaryHTTPStatusesThrowHTTPStatus() async {
        for statusCode in [403, 404, 500] {
            let api = makeAPI(statusCode: statusCode, data: Data("{}".utf8))

            do {
                _ = try await api.fetchLatest()
                XCTFail("Expected http status error for \(statusCode)")
            } catch let error as APIError {
                XCTAssertEqual(error, .httpStatus(statusCode))
            } catch {
                XCTFail("Unexpected error for \(statusCode): \(error)")
            }
        }
    }

    func testTimeoutThrowsTransportError() async {
        let api = makeAPI(error: URLError(.timedOut))

        do {
            _ = try await api.fetchLatest()
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
        let api = makeAPI(statusCode: 200, data: Data("{ broken".utf8))

        do {
            _ = try await api.fetchLatest()
            XCTFail("Expected decoding error")
        } catch let error as APIError {
            XCTAssertEqual(error, .decodingFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeAPI(json name: String) -> ZhihuDailyAPI {
        makeAPI(statusCode: 200, data: fixtureData(name))
    }

    private func makeAPI(statusCode: Int, data: Data) -> ZhihuDailyAPI {
        makeAPI(statusCode: statusCode, data: data, capture: nil)
    }

    private func makeAPI(statusCode: Int, data: Data, capture: ((URLRequest) -> Void)?) -> ZhihuDailyAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = { request in
            capture?(request)
            return MockURLProtocol.Response(statusCode: statusCode, data: data)
        }
        let session = URLSession(configuration: configuration)
        let httpClient = HTTPClient(session: session)
        return ZhihuDailyAPI(httpClient: httpClient)
    }

    private func makeAPI(error: Error) -> ZhihuDailyAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = { _ in
            throw error
        }
        let session = URLSession(configuration: configuration)
        let httpClient = HTTPClient(session: session)
        return ZhihuDailyAPI(httpClient: httpClient)
    }

    private func fixtureData(_ name: String) -> Data {
        let url = Bundle(for: Self.self).url(forResource: name, withExtension: "json")!
        return try! Data(contentsOf: url)
    }
}
