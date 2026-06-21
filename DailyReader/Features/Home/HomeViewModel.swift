import Foundation

struct DailySection: Identifiable, Equatable {
    var id: String { date }
    let date: String
    var stories: [StorySummary]
}

enum HomePhase: Equatable {
    case idle
    case loading
    case loaded(ContentSource)
    case empty
    case failed(String)
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var phase: HomePhase = .idle
    @Published private(set) var topStories: [TopStory] = []
    @Published private(set) var sections: [DailySection] = []
    @Published var bannerMessage: String?
    @Published var isLoadingMore = false

    private let apiClient: DailyAPIClient
    private let cacheStore: CacheStore
    private var loadedStoryIDs = Set<Int>()

    init(apiClient: DailyAPIClient, cacheStore: CacheStore) {
        self.apiClient = apiClient
        self.cacheStore = cacheStore
    }

    func load() async {
        guard phase == .idle || phase == .failed("") else { return }
        phase = .loading
        await loadLatest(allowCacheFallback: true)
    }

    func refresh() async {
        await loadLatest(allowCacheFallback: !sections.isEmpty)
    }

    func loadMore() async {
        guard !isLoadingMore, let oldestDate = sections.last?.date else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let response = try await apiClient.fetchBefore(date: oldestDate)
            await cacheStore.saveDaily(response)
            append(response: response)
        } catch {
            bannerMessage = "加载历史失败，已保留当前内容"
        }
    }

    private func loadLatest(allowCacheFallback: Bool) async {
        do {
            let response = try await apiClient.fetchLatest()
            await cacheStore.saveLatest(response)
            replace(with: response, source: .network)
            bannerMessage = nil
        } catch {
            if allowCacheFallback, let cached = await cacheStore.loadLatest() {
                let hadVisibleContent = !sections.isEmpty
                replace(with: cached.value, source: .cache(cached.cachedAt))
                bannerMessage = hadVisibleContent ? "刷新失败，已保留上次内容" : "当前离线，正在显示缓存内容"
            } else if sections.isEmpty {
                phase = .failed("内容加载失败，请检查网络后重试")
            } else {
                bannerMessage = "刷新失败，已保留上次内容"
            }
        }
    }

    private func replace(with response: DailyResponse, source: ContentSource) {
        loadedStoryIDs = []
        topStories = response.topStories
        let filteredStories = uniqueStories(from: response.stories)
        sections = filteredStories.isEmpty ? [] : [DailySection(date: response.date, stories: filteredStories)]
        phase = filteredStories.isEmpty && topStories.isEmpty ? .empty : .loaded(source)
    }

    private func append(response: DailyResponse) {
        let filteredStories = uniqueStories(from: response.stories)
        guard !filteredStories.isEmpty else { return }
        sections.append(DailySection(date: response.date, stories: filteredStories))
    }

    private func uniqueStories(from stories: [StorySummary]) -> [StorySummary] {
        stories.filter { story in
            guard !loadedStoryIDs.contains(story.id), !story.title.isEmpty else { return false }
            loadedStoryIDs.insert(story.id)
            return true
        }
    }
}
