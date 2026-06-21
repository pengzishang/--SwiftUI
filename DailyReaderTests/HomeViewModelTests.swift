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

    func testNetworkFailureWithoutCacheShowsRetryableErrorState() async {
        let api = MockDailyAPIClient()
        api.latestResult = .failure(APIError.transport("offline"))
        let viewModel = HomeViewModel(apiClient: api, cacheStore: DiskCacheStore(rootURL: temporaryRoot()))

        await viewModel.load()

        XCTAssertEqual(viewModel.phase, .failed("网络不可用，请检查连接后重试"))
        XCTAssertTrue(viewModel.sections.isEmpty)
        XCTAssertNil(viewModel.bannerMessage)
    }

    func testRefreshFailureWithoutCacheKeepsVisibleContent() async {
        let api = MockDailyAPIClient()
        let viewModel = HomeViewModel(apiClient: api, cacheStore: DiskCacheStore(rootURL: temporaryRoot()))

        await viewModel.load()
        api.latestResult = .failure(APIError.transport("offline"))
        await viewModel.refresh()

        XCTAssertEqual(viewModel.sections.flatMap(\.stories).map(\.id), [1, 2])
        XCTAssertEqual(viewModel.bannerMessage, "刷新失败，已保留上次内容")
    }

    func testRefreshFailureKeepsLoadedHistorySections() async {
        let api = MockDailyAPIClient()
        let viewModel = HomeViewModel(apiClient: api, cacheStore: DiskCacheStore(rootURL: temporaryRoot()))

        await viewModel.load()
        await viewModel.loadMore()
        api.latestResult = .failure(APIError.transport("offline"))
        await viewModel.refresh()

        XCTAssertEqual(viewModel.sections.map(\.date), ["20260621", "20260620"])
        XCTAssertEqual(viewModel.sections.flatMap(\.stories).map(\.id), [1, 2, 3])
        XCTAssertEqual(viewModel.bannerMessage, "刷新失败，已保留上次内容")
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

    func testLoadMoreFailureFallsBackToCachedPreviousDailyList() async {
        let store = DiskCacheStore(rootURL: temporaryRoot())
        await store.saveDaily(.historyFixture)
        let api = MockDailyAPIClient()
        api.beforeResult = .failure(APIError.transport("offline"))
        let viewModel = HomeViewModel(apiClient: api, cacheStore: store)

        await viewModel.load()
        await viewModel.loadMore()

        XCTAssertEqual(viewModel.sections.map(\.date), ["20260621", "20260620"])
        XCTAssertEqual(viewModel.sections.flatMap(\.stories).map(\.id), [1, 2, 3])
        XCTAssertEqual(viewModel.historyLoadState, .idle)
        XCTAssertEqual(viewModel.bannerMessage, "当前离线，正在显示缓存内容")
    }

    func testReadStoryIDsPersistAcrossViewModelInstances() {
        let key = "DailyReader.readStoryIDs"
        UserDefaults.standard.removeObject(forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

        let firstViewModel = HomeViewModel(apiClient: MockDailyAPIClient(), cacheStore: DiskCacheStore(rootURL: temporaryRoot()))
        firstViewModel.markStoryRead(42)

        let secondViewModel = HomeViewModel(apiClient: MockDailyAPIClient(), cacheStore: DiskCacheStore(rootURL: temporaryRoot()))
        XCTAssertTrue(secondViewModel.isStoryRead(42))
    }

    func testHideAndRestoreStory() async {
        let hiddenKey = "DailyReader.hiddenStories"
        UserDefaults.standard.removeObject(forKey: hiddenKey)
        defer { UserDefaults.standard.removeObject(forKey: hiddenKey) }

        let api = MockDailyAPIClient()
        let viewModel = HomeViewModel(apiClient: api, cacheStore: DiskCacheStore(rootURL: temporaryRoot()))
        await viewModel.load()

        let storyToHide = StorySummary(id: 1, title: "Story 1", images: [], hint: "Hint 1", url: nil)
        
        // Hide
        viewModel.hideStory(storyToHide, date: "20260621")
        
        XCTAssertTrue(viewModel.isStoryHidden(1))
        XCTAssertFalse(viewModel.visibleSections.flatMap(\.stories).contains(where: { $0.id == 1 }))
        XCTAssertTrue(viewModel.hiddenSections.flatMap(\.stories).contains(where: { $0.id == 1 }))
        XCTAssertEqual(viewModel.hiddenSections.first?.date, "20260621")

        // Hide the second story in the same section to verify the section disappears
        let secondStory = StorySummary(id: 2, title: "Story 2", images: [], hint: "Hint 2", url: nil)
        viewModel.hideStory(secondStory, date: "20260621")
        XCTAssertTrue(viewModel.visibleSections.isEmpty) // The whole section was empty, so it's hidden!

        // Restore
        viewModel.restoreStory(1)
        XCTAssertFalse(viewModel.isStoryHidden(1))
        XCTAssertTrue(viewModel.visibleSections.flatMap(\.stories).contains(where: { $0.id == 1 }))
        XCTAssertFalse(viewModel.hiddenSections.flatMap(\.stories).contains(where: { $0.id == 1 }))
    }

    func testFavoriteStoryToggle() async {
        let favoriteKey = "DailyReader.favoriteStories"
        UserDefaults.standard.removeObject(forKey: favoriteKey)
        defer { UserDefaults.standard.removeObject(forKey: favoriteKey) }

        let api = MockDailyAPIClient()
        let viewModel = HomeViewModel(apiClient: api, cacheStore: DiskCacheStore(rootURL: temporaryRoot()))
        await viewModel.load()

        let story = StorySummary(id: 1, title: "Story 1", images: [], hint: "Hint 1", url: nil)
        
        // Favorite
        viewModel.toggleFavorite(story, date: "20260621")
        XCTAssertTrue(viewModel.isStoryFavorited(1))
        XCTAssertTrue(viewModel.favoriteSections.flatMap(\.stories).contains(where: { $0.id == 1 }))

        // Unfavorite
        viewModel.toggleFavorite(story, date: "20260621")
        XCTAssertFalse(viewModel.isStoryFavorited(1))
        XCTAssertFalse(viewModel.favoriteSections.flatMap(\.stories).contains(where: { $0.id == 1 }))
    }

    func testReadStoryToggleAndSync() async {
        let readIDsKey = "DailyReader.readStoryIDs"
        let readStoriesKey = "DailyReader.readStories"
        UserDefaults.standard.removeObject(forKey: readIDsKey)
        UserDefaults.standard.removeObject(forKey: readStoriesKey)
        defer {
            UserDefaults.standard.removeObject(forKey: readIDsKey)
            UserDefaults.standard.removeObject(forKey: readStoriesKey)
        }

        let api = MockDailyAPIClient()
        let viewModel = HomeViewModel(apiClient: api, cacheStore: DiskCacheStore(rootURL: temporaryRoot()))
        await viewModel.load()

        let story = StorySummary(id: 1, title: "Story 1", images: [], hint: "Hint 1", url: nil)
        
        // Mark read via toggle
        viewModel.toggleRead(story, date: "20260621")
        XCTAssertTrue(viewModel.isStoryRead(1))
        XCTAssertTrue(viewModel.readSections.flatMap(\.stories).contains(where: { $0.id == 1 }))

        // Mark unread via toggle
        viewModel.toggleRead(story, date: "20260621")
        XCTAssertFalse(viewModel.isStoryRead(1))
        XCTAssertFalse(viewModel.readSections.flatMap(\.stories).contains(where: { $0.id == 1 }))

        // Mark read via detail onAppear style
        viewModel.markStoryRead(story, date: "20260621")
        XCTAssertTrue(viewModel.isStoryRead(1))
        XCTAssertTrue(viewModel.readSections.flatMap(\.stories).contains(where: { $0.id == 1 }))
    }

    func testPersistenceAcrossInstances() {
        let hiddenKey = "DailyReader.hiddenStories"
        let favoriteKey = "DailyReader.favoriteStories"
        let readIDsKey = "DailyReader.readStoryIDs"
        let readStoriesKey = "DailyReader.readStories"
        
        UserDefaults.standard.removeObject(forKey: hiddenKey)
        UserDefaults.standard.removeObject(forKey: favoriteKey)
        UserDefaults.standard.removeObject(forKey: readIDsKey)
        UserDefaults.standard.removeObject(forKey: readStoriesKey)
        
        defer {
            UserDefaults.standard.removeObject(forKey: hiddenKey)
            UserDefaults.standard.removeObject(forKey: favoriteKey)
            UserDefaults.standard.removeObject(forKey: readIDsKey)
            UserDefaults.standard.removeObject(forKey: readStoriesKey)
        }

        let firstViewModel = HomeViewModel(apiClient: MockDailyAPIClient(), cacheStore: DiskCacheStore(rootURL: temporaryRoot()))
        let story = StorySummary(id: 1, title: "Story 1", images: [], hint: "Hint 1", url: nil)
        
        firstViewModel.hideStory(story, date: "20260621")
        firstViewModel.toggleFavorite(story, date: "20260621")
        firstViewModel.markStoryRead(story, date: "20260621")

        let secondViewModel = HomeViewModel(apiClient: MockDailyAPIClient(), cacheStore: DiskCacheStore(rootURL: temporaryRoot()))
        
        XCTAssertTrue(secondViewModel.isStoryHidden(1))
        XCTAssertTrue(secondViewModel.isStoryFavorited(1))
        XCTAssertTrue(secondViewModel.isStoryRead(1))
        XCTAssertEqual(secondViewModel.hiddenSections.flatMap(\.stories).map(\.id), [1])
        XCTAssertEqual(secondViewModel.favoriteSections.flatMap(\.stories).map(\.id), [1])
        XCTAssertEqual(secondViewModel.readSections.flatMap(\.stories).map(\.id), [1])
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
