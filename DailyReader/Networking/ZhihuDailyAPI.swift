import Foundation

final class ZhihuDailyAPI: DailyAPIClient {
    private let httpClient: HTTPClient

    init(httpClient: HTTPClient = HTTPClient()) {
        self.httpClient = httpClient
    }

    func fetchLatest() async throws -> DailyResponse {
        try await httpClient.get("/news/latest")
    }

    func fetchBefore(date: String) async throws -> DailyResponse {
        try await httpClient.get("/news/before/\(date)")
    }

    func fetchDetail(id: Int) async throws -> ArticleDetail {
        try await httpClient.get("/news/\(id)")
    }
}
