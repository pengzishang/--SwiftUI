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
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = { _ in
            MockURLProtocol.Response(statusCode: statusCode, data: data)
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
