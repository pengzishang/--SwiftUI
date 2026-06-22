import SwiftUI

struct AppRootView: View {
    @StateObject private var homeViewModel = AppEnvironment.makeHomeViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(viewModel: homeViewModel)
            }
            .tabItem {
                Label("日报", systemImage: "newspaper")
            }
            .tag(0)

            NavigationStack {
                FavoritesView(viewModel: homeViewModel)
            }
            .tabItem {
                Label("收藏", systemImage: "star")
            }
            .tag(1)

            NavigationStack {
                ReadStoriesView(viewModel: homeViewModel)
            }
            .tabItem {
                Label("已读", systemImage: "checkmark.circle")
            }
            .tag(2)

            NavigationStack {
                SettingsView(viewModel: homeViewModel)
            }
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
            .tag(3)
        }
    }
}

enum AppEnvironment {
    private static let cache = DiskCacheStore()

    @MainActor
    static func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(apiClient: makeAPIClient(), cacheStore: cache)
    }

    @MainActor
    static func makeDetailViewModel(story: StorySummary) -> ArticleDetailViewModel {
        ArticleDetailViewModel(
            story: story,
            apiClient: makeAPIClient(),
            cacheStore: cache
        )
    }

    private static func makeAPIClient() -> DailyAPIClient {
        let processInfo = ProcessInfo.processInfo
        if processInfo.arguments.contains("-UITestMode") {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: "DailyReader.readStoryIDs")
            defaults.removeObject(forKey: "DailyReader.hiddenStories")
            defaults.removeObject(forKey: "DailyReader.favoriteStories")
            defaults.removeObject(forKey: "DailyReader.readStories")

            try? FileManager.default.removeItem(
                at: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
                    .first!
                    .appendingPathComponent("DailyReaderCache", isDirectory: true)
            )
            let scenario = processInfo.environment["MOCK_SCENARIO"] ?? "latest_success"
            return LocalFixtureDailyAPIClient(scenario: scenario)
        }
        return ZhihuDailyAPI()
    }
}
