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
    @Published private(set) var readStoryIDs: Set<Int>
    @Published private(set) var hiddenStories: [HiddenStory] = []
    @Published private(set) var favoriteStories: [FavoriteStory] = []
    @Published private(set) var readStories: [ReadStory] = []
    @Published var bannerMessage: String?

    private let apiClient: DailyAPIClient
    private let cacheStore: CacheStore
    private var loadedStoryIDs = Set<Int>()
    private var hasAttemptedInitialLoad = false
    private let readStoryIDsKey = "DailyReader.readStoryIDs"
    private let hiddenStoriesKey = "DailyReader.hiddenStories"
    private let favoriteStoriesKey = "DailyReader.favoriteStories"
    private let readStoriesKey = "DailyReader.readStories"

    init(apiClient: DailyAPIClient, cacheStore: CacheStore) {
        self.apiClient = apiClient
        self.cacheStore = cacheStore
        self.readStoryIDs = Set(UserDefaults.standard.array(forKey: readStoryIDsKey) as? [Int] ?? [])
        
        if let data = UserDefaults.standard.data(forKey: hiddenStoriesKey),
           let list = try? JSONDecoder().decode([HiddenStory].self, from: data) {
            self.hiddenStories = list
        } else {
            self.hiddenStories = []
        }

        if let data = UserDefaults.standard.data(forKey: favoriteStoriesKey),
           let list = try? JSONDecoder().decode([FavoriteStory].self, from: data) {
            self.favoriteStories = list
        } else {
            self.favoriteStories = []
        }

        if let data = UserDefaults.standard.data(forKey: readStoriesKey),
           let list = try? JSONDecoder().decode([ReadStory].self, from: data) {
            self.readStories = list
        } else {
            self.readStories = []
        }
    }

    // MARK: - Filtered computed sections
    var visibleSections: [DailySection] {
        sections.map { section in
            var sec = section
            sec.stories = section.stories.filter { story in
                !isStoryHidden(story.id) && !isStoryFavorited(story.id) && !isStoryRead(story.id)
            }
            return sec
        }.filter { !$0.stories.isEmpty }
    }

    var hiddenSections: [DailySection] {
        let grouped = Dictionary(grouping: hiddenStories, by: { $0.date })
        return grouped.map { (date, list) in
            DailySection(date: date, stories: list.map { $0.story })
        }
        .filter { !$0.stories.isEmpty }
        .sorted(by: { $0.date > $1.date })
    }

    var favoriteSections: [DailySection] {
        let visibleFavorites = favoriteStories.filter { !isStoryHidden($0.id) }
        let grouped = Dictionary(grouping: visibleFavorites, by: { $0.date })
        return grouped.map { (date, list) in
            DailySection(date: date, stories: list.map { $0.story })
        }
        .filter { !$0.stories.isEmpty }
        .sorted(by: { $0.date > $1.date })
    }

    var readSections: [DailySection] {
        let visibleRead = readStories.filter { !isStoryHidden($0.id) && !isStoryFavorited($0.id) }
        let grouped = Dictionary(grouping: visibleRead, by: { $0.date })
        return grouped.map { (date, list) in
            DailySection(date: date, stories: list.map { $0.story })
        }
        .filter { !$0.stories.isEmpty }
        .sorted(by: { $0.date > $1.date })
    }

    // MARK: - API Actions
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

    // MARK: - Status updates & Persistence
    func markStoryRead(_ storyID: Int) {
        guard readStoryIDs.insert(storyID).inserted else { return }
        UserDefaults.standard.set(Array(readStoryIDs), forKey: readStoryIDsKey)
    }

    func markStoryRead(_ story: StorySummary, date: String) {
        guard readStoryIDs.insert(story.id).inserted else { return }
        UserDefaults.standard.set(Array(readStoryIDs), forKey: readStoryIDsKey)
        if !readStories.contains(where: { $0.id == story.id }) {
            readStories.append(ReadStory(date: date, story: story))
            saveReadStories()
        }
    }

    func isStoryRead(_ storyID: Int) -> Bool {
        readStoryIDs.contains(storyID)
    }

    func hideStory(_ story: StorySummary, date: String) {
        guard !hiddenStories.contains(where: { $0.id == story.id }) else { return }
        hiddenStories.append(HiddenStory(date: date, story: story))
        saveHiddenStories()
    }

    func restoreStory(_ storyID: Int) {
        hiddenStories.removeAll(where: { $0.id == storyID })
        saveHiddenStories()
    }

    func isStoryHidden(_ storyID: Int) -> Bool {
        hiddenStories.contains(where: { $0.id == storyID })
    }

    func toggleFavorite(_ story: StorySummary, date: String) {
        if let index = favoriteStories.firstIndex(where: { $0.id == story.id }) {
            favoriteStories.remove(at: index)
            restoreStory(story.id)
        } else {
            favoriteStories.append(FavoriteStory(date: date, story: story))
        }
        saveFavoriteStories()
    }

    func isStoryFavorited(_ storyID: Int) -> Bool {
        favoriteStories.contains(where: { $0.id == storyID })
    }

    func toggleRead(_ story: StorySummary, date: String) {
        if readStoryIDs.contains(story.id) {
            readStoryIDs.remove(story.id)
            readStories.removeAll(where: { $0.id == story.id })
        } else {
            readStoryIDs.insert(story.id)
            if !readStories.contains(where: { $0.id == story.id }) {
                readStories.append(ReadStory(date: date, story: story))
            }
        }
        UserDefaults.standard.set(Array(readStoryIDs), forKey: readStoryIDsKey)
        saveReadStories()
    }

    private func saveHiddenStories() {
        if let data = try? JSONEncoder().encode(hiddenStories) {
            UserDefaults.standard.set(data, forKey: hiddenStoriesKey)
        }
    }

    private func saveFavoriteStories() {
        if let data = try? JSONEncoder().encode(favoriteStories) {
            UserDefaults.standard.set(data, forKey: favoriteStoriesKey)
        }
    }

    private func saveReadStories() {
        if let data = try? JSONEncoder().encode(readStories) {
            UserDefaults.standard.set(data, forKey: readStoriesKey)
        }
    }

    var thresholdStoryID: Int? {
        let allStories = sections.flatMap { $0.stories }
        guard !allStories.isEmpty else { return nil }
        let thresholdIndex = max(0, allStories.count - 4)
        return allStories[thresholdIndex].id
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
