import XCTest
@testable import DailyReader

@MainActor
final class HotListViewModelTests: XCTestCase {
    func testLoadUsesSameDayCacheAfterFirstSuccessfulRefresh() async {
        let service = MockDailyService()
        let cacheStore = InMemoryCacheStore()
        let viewModel = HotListViewModel(repository: makeRepository(
            service: service,
            cacheStore: cacheStore,
            now: { Date(timeIntervalSince1970: 1_782_446_400) }
        ))

        await viewModel.load()
        await viewModel.load()

        XCTAssertEqual(service.hotListCallCount, 1)
    }

    func testManualRefreshIgnoresSameDayCacheAndUpdatesItems() async {
        let service = MockDailyService()
        let cacheStore = InMemoryCacheStore()
        let viewModel = HotListViewModel(repository: makeRepository(
            service: service,
            cacheStore: cacheStore,
            now: { Date(timeIntervalSince1970: 1_782_446_400) }
        ))

        await viewModel.load()
        service.hotListResult = .success(.fixture(questionID: 1002, title: "手动刷新后的热榜"))
        await viewModel.refresh()

        XCTAssertEqual(service.hotListCallCount, 2)
        XCTAssertEqual(viewModel.loadedItems.first?.target.title, "手动刷新后的热榜")
    }

    func testLoadRefreshesWhenCachedHotListIsFromPreviousDay() async {
        let service = MockDailyService()
        service.hotListResult = .success(.fixture(questionID: 1002, title: "新一天热榜"))
        let cacheStore = InMemoryCacheStore(
            hotList: CachedValue(
                value: .fixture(questionID: 1001, title: "昨天热榜"),
                cachedAt: Date(timeIntervalSince1970: 1_782_360_000)
            )
        )
        let viewModel = HotListViewModel(repository: makeRepository(
            service: service,
            cacheStore: cacheStore,
            now: { Date(timeIntervalSince1970: 1_782_446_400) }
        ))

        await viewModel.load()

        XCTAssertEqual(service.hotListCallCount, 1)
        XCTAssertEqual(viewModel.loadedItems.first?.target.title, "新一天热榜")
    }
}

private extension HotListViewModel {
    var loadedItems: [HotItem] {
        if case .loaded(let items) = phase {
            return items
        }
        return []
    }
}

private actor InMemoryCacheStore: CacheStore {
    private var hotList: CachedValue<HotListResponse>?

    init(hotList: CachedValue<HotListResponse>? = nil) {
        self.hotList = hotList
    }

    func saveLatest(_ response: DailyResponse) async {}
    func loadLatest() async -> CachedValue<DailyResponse>? { nil }
    func saveDaily(_ response: DailyResponse) async {}
    func loadDaily(date: String) async -> CachedValue<DailyResponse>? { nil }
    func loadDaily(dates: [String]) async -> [String: CachedValue<DailyResponse>] { [:] }
    func saveDetail(_ detail: ArticleDetail) async {}
    func loadDetail(id: Int) async -> CachedValue<ArticleDetail>? { nil }
    func saveHomeFeed(
        sections: [DailySection],
        topStories: [TopStory],
        historyCursor: String?
    ) async {}
    func loadHomeFeed() async -> CachedValue<CachedHomeFeed>? { nil }

    func saveHotList(_ response: HotListResponse) async {
        hotList = CachedValue(value: response, cachedAt: Date(timeIntervalSince1970: 1_782_446_400))
    }

    func loadHotList() async -> CachedValue<HotListResponse>? {
        hotList
    }
}
