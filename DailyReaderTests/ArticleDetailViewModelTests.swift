import XCTest
@testable import DailyReader

@MainActor
final class ArticleDetailViewModelTests: XCTestCase {
    func testLoadDetailUsesDetailShareURLFirst() async {
        let viewModel = ArticleDetailViewModel(
            story: StorySummary(id: 1, title: "列表标题", url: "https://example.com/list"),
            apiClient: MockDailyAPIClient(),
            cacheStore: DiskCacheStore(rootURL: temporaryRoot())
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.shareURL?.absoluteString, "https://example.com/1")
    }

    func testLoadDetailFallsBackToDetailURLBeforeListURL() async {
        let api = MockDailyAPIClient()
        api.detailResult = .success(
            ArticleDetail(
                id: 1,
                title: "第一篇日报",
                body: "<p>正文</p>",
                shareURL: nil,
                url: "https://daily.example.com/detail-url"
            )
        )
        let viewModel = ArticleDetailViewModel(
            story: StorySummary(id: 1, title: "列表标题", url: "https://example.com/list"),
            apiClient: api,
            cacheStore: DiskCacheStore(rootURL: temporaryRoot())
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.shareURL?.absoluteString, "https://daily.example.com/detail-url")
    }

    func testLoadDetailFallsBackToCachedDetail() async {
        let store = DiskCacheStore(rootURL: temporaryRoot())
        await store.saveDetail(.fixture)
        let api = MockDailyAPIClient()
        api.detailResult = .failure(APIError.transport("offline"))
        let viewModel = ArticleDetailViewModel(
            story: StorySummary(id: 1, title: "列表标题"),
            apiClient: api,
            cacheStore: store
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.bannerMessage, "当前离线，正在显示缓存内容")
        XCTAssertTrue(viewModel.phase.isCacheLoaded)
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}

private extension ArticleDetailPhase {
    var isCacheLoaded: Bool {
        if case .loaded(_, .cache) = self { return true }
        return false
    }
}
