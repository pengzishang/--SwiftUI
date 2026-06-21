import XCTest
@testable import DailyReader

@MainActor
final class HomeViewModelTests: XCTestCase {
    func testLoadLatestShowsNetworkContent() async {
        let api = MockDailyAPIClient()
        let viewModel = HomeViewModel(apiClient: api, cacheStore: DiskCacheStore(rootURL: temporaryRoot()))

        await viewModel.load()

        XCTAssertEqual(viewModel.topStories.count, 1)
        XCTAssertEqual(viewModel.sections.first?.stories.count, 2)
        XCTAssertEqual(viewModel.phase, .loaded(.network))
    }

    func testNetworkFailureFallsBackToCachedLatest() async {
        let store = DiskCacheStore(rootURL: temporaryRoot())
        await store.saveLatest(.fixture)
        let api = MockDailyAPIClient()
        api.latestResult = .failure(APIError.transport("offline"))
        let viewModel = HomeViewModel(apiClient: api, cacheStore: store)

        await viewModel.load()

        XCTAssertEqual(viewModel.sections.first?.stories.count, 2)
        XCTAssertEqual(viewModel.bannerMessage, "当前离线，正在显示缓存内容")
        XCTAssertTrue(viewModel.phase.isCacheLoaded)
    }

    func testLoadMoreDeduplicatesStories() async {
        let api = MockDailyAPIClient()
        let viewModel = HomeViewModel(apiClient: api, cacheStore: DiskCacheStore(rootURL: temporaryRoot()))

        await viewModel.load()
        await viewModel.loadMore()

        XCTAssertEqual(viewModel.sections.flatMap(\.stories).map(\.id), [1, 2, 3])
        XCTAssertEqual(viewModel.historyLoadState, .idle)
    }

    func testLoadMoreFailureKeepsExistingStoriesAndExposesRetryState() async {
        let api = MockDailyAPIClient()
        api.beforeResult = .failure(APIError.httpStatus(502))
        let viewModel = HomeViewModel(apiClient: api, cacheStore: DiskCacheStore(rootURL: temporaryRoot()))

        await viewModel.load()
        await viewModel.loadMore()

        XCTAssertEqual(viewModel.sections.flatMap(\.stories).map(\.id), [1, 2])
        XCTAssertEqual(viewModel.historyLoadState, .failed("加载历史失败，已保留当前内容"))
        XCTAssertEqual(viewModel.bannerMessage, "加载历史失败，已保留当前内容")
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}

private extension HomePhase {
    var isCacheLoaded: Bool {
        if case .loaded(.cache) = self { return true }
        return false
    }
}
