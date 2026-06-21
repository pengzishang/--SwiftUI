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

enum HistoryLoadState: Equatable {
    case idle
    case loading
    case failed(String)
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var phase: HomePhase = .idle
    @Published private(set) var topStories: [TopStory] = []
    @Published private(set) var sections: [DailySection] = []
    @Published private(set) var historyLoadState: HistoryLoadState = .idle
    @Published var bannerMessage: String?

    private let apiClient: DailyAPIClient
    private let cacheStore: CacheStore
    private var loadedStoryIDs = Set<Int>()
    private var hasAttemptedInitialLoad = false

    init(apiClient: DailyAPIClient, cacheStore: CacheStore) {
        self.apiClient = apiClient
        self.cacheStore = cacheStore
    }

    func load() async {
        guard !hasAttemptedInitialLoad else { return }
        hasAttemptedInitialLoad = true
        phase = .loading
        await loadLatest(allowCacheFallback: true)
    }

    func refresh() async {
        await loadLatest(allowCacheFallback: true)
    }

    func loadMore() async {
        guard historyLoadState != .loading, let oldestDate = sections.last?.date else { return }
        historyLoadState = .loading

        do {
            let response = try await apiClient.fetchBefore(date: oldestDate)
            await cacheStore.saveDaily(response)
            append(response: response)
            historyLoadState = .idle
            bannerMessage = nil
        } catch {
            if let fallbackDate = Self.previousDateString(before: oldestDate),
               let cached = await cacheStore.loadDaily(date: fallbackDate) {
                append(response: cached.value)
                historyLoadState = .idle
                bannerMessage = "当前离线，正在显示缓存内容"
            } else {
                let message = "加载历史失败，已保留当前内容"
                historyLoadState = .failed(message)
                bannerMessage = message
            }
        }
    }

    private func loadLatest(allowCacheFallback: Bool) async {
        do {
            let response = try await apiClient.fetchLatest()
            await cacheStore.saveLatest(response)
            replace(with: response, source: .network)
            bannerMessage = nil
        } catch {
            if allowCacheFallback, sections.isEmpty, let cached = await cacheStore.loadLatest() {
                replace(with: cached.value, source: .cache(cached.cachedAt))
                bannerMessage = "当前离线，正在显示缓存内容"
            } else if sections.isEmpty {
                phase = .failed("网络不可用，请检查连接后重试")
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
        historyLoadState = .idle
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

    private static func previousDateString(before dateString: String) -> String? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd"

        guard
            let date = formatter.date(from: dateString),
            let previousDate = formatter.calendar.date(byAdding: .day, value: -1, to: date)
        else {
            return nil
        }
        return formatter.string(from: previousDate)
    }
}
