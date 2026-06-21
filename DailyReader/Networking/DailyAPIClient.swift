import Foundation

protocol DailyAPIClient {
    func fetchLatest() async throws -> DailyResponse
    func fetchBefore(date: String) async throws -> DailyResponse
    func fetchDetail(id: Int) async throws -> ArticleDetail
}
