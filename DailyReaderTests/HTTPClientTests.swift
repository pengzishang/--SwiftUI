import XCTest
@testable import DailyReader

final class HTTPClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testExecuteSendsTypedEndpointAndDecodesResponse() async throws {
        var capturedRequest: URLRequest?
        let client = makeClient { request in
            capturedRequest = request
            return MockURLProtocol.Response(
                statusCode: 200,
                data: self.fixtureData("latest_success")
            )
        }

        let response = try await client.execute(ZhihuEndpoints.latest())

        XCTAssertEqual(response.date, "20260621")
        XCTAssertEqual(capturedRequest?.url?.absoluteString, "https://daily.zhihu.com/api/4/news/latest")
        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "User-Agent"), HTTPClient.browserUserAgent)
    }

    func testExecuteMapsNonSuccessStatus() async {
        let client = makeClient { _ in
            MockURLProtocol.Response(statusCode: 503, data: Data("{}".utf8))
        }

        do {
            _ = try await client.execute(ZhihuEndpoints.latest())
            XCTFail("Expected HTTP status error")
        } catch let error as APIError {
            XCTAssertEqual(error, .httpStatus(503))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testExecuteMapsDecodingFailure() async {
        let client = makeClient { _ in
            MockURLProtocol.Response(statusCode: 200, data: Data("{broken".utf8))
        }

        do {
            _ = try await client.execute(ZhihuEndpoints.latest())
            XCTFail("Expected decoding error")
        } catch let error as APIError {
            XCTAssertEqual(error, .decodingFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testConcurrentRequestsCreateIndependentDecoders() async throws {
        let tracker = DecoderFactoryTracker()
        let client = makeClient(
            decoderFactory: {
                tracker.makeDecoder()
            }
        ) { _ in
            MockURLProtocol.Response(
                statusCode: 200,
                data: self.fixtureData("latest_success")
            )
        }

        try await withThrowingTaskGroup(of: DailyResponse.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    try await client.execute(ZhihuEndpoints.latest())
                }
            }
            for try await response in group {
                XCTAssertEqual(response.date, "20260621")
            }
        }

        XCTAssertEqual(tracker.creationCount, 8)
        XCTAssertEqual(tracker.uniqueDecoderCount, 8)
    }

    private func makeClient(
        decoderFactory: @escaping HTTPClient.DecoderFactory = { JSONDecoder() },
        handler: @escaping (URLRequest) throws -> MockURLProtocol.Response
    ) -> HTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = handler
        return HTTPClient(
            session: URLSession(configuration: configuration),
            decoderFactory: decoderFactory
        )
    }

    private func fixtureData(_ name: String) -> Data {
        let url = Bundle(for: Self.self).url(forResource: name, withExtension: "json")!
        return try! Data(contentsOf: url)
    }
}

private final class DecoderFactoryTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var decoders: [JSONDecoder] = []

    var creationCount: Int {
        lock.withLock { decoders.count }
    }

    var uniqueDecoderCount: Int {
        lock.withLock { Set(decoders.map(ObjectIdentifier.init)).count }
    }

    func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        lock.withLock {
            decoders.append(decoder)
        }
        return decoder
    }
}
