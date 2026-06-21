import SwiftUI

struct AppRootView: View {
    @StateObject private var homeViewModel = AppEnvironment.makeHomeViewModel()

    var body: some View {
        NavigationStack {
            HomeView(viewModel: homeViewModel)
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
            if processInfo.arguments.contains("-ResetCache") {
                try? FileManager.default.removeItem(
                    at: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
                        .first!
                        .appendingPathComponent("DailyReaderCache", isDirectory: true)
                )
            }
            let scenario = processInfo.environment["MOCK_SCENARIO"] ?? "latest_success"
            return LocalFixtureDailyAPIClient(scenario: scenario)
        }
        return ZhihuDailyAPI()
    }
}
