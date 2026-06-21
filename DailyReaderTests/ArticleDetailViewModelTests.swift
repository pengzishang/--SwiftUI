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
        XCTAssertEqual(viewModel.shareTitle, "第一篇日报")
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

    func testLoadDetailFailureWithoutCacheShowsRetryableError() async {
        let api = MockDailyAPIClient()
        api.detailResult = .failure(APIError.transport("offline"))
        let viewModel = ArticleDetailViewModel(
            story: StorySummary(id: 1, title: "列表标题"),
            apiClient: api,
            cacheStore: DiskCacheStore(rootURL: temporaryRoot())
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.phase, .failed("文章加载失败，请稍后重试"))
        XCTAssertNil(viewModel.shareURL)
    }

    func testMissingShareLinkDoesNotProduceFallbackGarbageURL() async {
        let api = MockDailyAPIClient()
        api.detailResult = .success(
            ArticleDetail(
                id: 1,
                title: "无分享链接文章",
                body: "<p>正文</p>",
                shareURL: nil,
                url: nil
            )
        )
        let viewModel = ArticleDetailViewModel(
            story: StorySummary(id: 1, title: "列表标题", url: nil),
            apiClient: api,
            cacheStore: DiskCacheStore(rootURL: temporaryRoot())
        )

        await viewModel.load()

        XCTAssertNil(viewModel.shareURL)
    }

    func testInvalidShareLinkIsRejected() async {
        let api = MockDailyAPIClient()
        api.detailResult = .success(
            ArticleDetail(
                id: 1,
                title: "无效分享链接文章",
                body: "<p>正文</p>",
                shareURL: "javascript:alert(1)",
                url: "not-a-valid-article-url"
            )
        )
        let viewModel = ArticleDetailViewModel(
            story: StorySummary(id: 1, title: "列表标题", url: "ftp://example.com/story"),
            apiClient: api,
            cacheStore: DiskCacheStore(rootURL: temporaryRoot())
        )

        await viewModel.load()

        XCTAssertNil(viewModel.shareURL)
    }

    func testShareTitleUsesDisplayedDetailTitle() async {
        let api = MockDailyAPIClient()
        api.detailResult = .success(
            ArticleDetail(
                id: 1,
                title: "详情标题",
                body: "<p>正文</p>",
                shareURL: "https://example.com/detail-title"
            )
        )
        let viewModel = ArticleDetailViewModel(
            story: StorySummary(id: 1, title: "列表标题", url: "https://example.com/list-title"),
            apiClient: api,
            cacheStore: DiskCacheStore(rootURL: temporaryRoot())
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.shareTitle, "详情标题")
    }

    func testEmptyBodyStillLoadsDetailForUnavailableContentState() async {
        let api = MockDailyAPIClient()
        api.detailResult = .success(
            ArticleDetail(
                id: 1,
                title: "空正文",
                body: "",
                shareURL: "https://example.com/empty"
            )
        )
        let viewModel = ArticleDetailViewModel(
            story: StorySummary(id: 1, title: "列表标题"),
            apiClient: api,
            cacheStore: DiskCacheStore(rootURL: temporaryRoot())
        )

        await viewModel.load()

        if case .loaded(let detail, .network) = viewModel.phase {
            XCTAssertEqual(detail.body, "")
        } else {
            XCTFail("Expected loaded detail with empty body fallback content state")
        }
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
