import SwiftUI

// 「设置」并入“我的”页头部，底部保留三项核心导航。
struct AppRootView: View {
    @StateObject private var homeViewModel = AppEnvironment.makeHomeViewModel()
    @StateObject private var aiCoordinator = AppEnvironment.makeAIChatCoordinator()
    @StateObject private var authenticationViewModel = AppEnvironment.makeAuthenticationViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // 1. Daily (Home)
            NavigationStack {
                HomeView(viewModel: homeViewModel)
                    .enablesInteractiveSwipeBack()
            }
            .tabItem {
                Label("日报", systemImage: "newspaper")
            }
            .tag(0)

            // 2. Hot List
            NavigationStack {
                HotListView(
                    viewModel: AppEnvironment.makeHotListViewModel(),
                    homeViewModel: homeViewModel,
                    makeAnswersViewModel: AppEnvironment.makeAnswersViewModel(questionID:)
                )
                .enablesInteractiveSwipeBack()
            }
            .tabItem {
                Label("热榜", systemImage: "flame")
            }
            .tag(1)

            // 3. Me (bookroom + settings entry)
            NavigationStack {
                MeView(
                    viewModel: homeViewModel,
                    authenticationViewModel: authenticationViewModel
                )
                    .enablesInteractiveSwipeBack()
            }
            .tabItem {
                Label("我的", systemImage: "person.crop.circle")
            }
            .tag(2)
        }
        // 全局强调色：靛蓝（蓝黑墨水），覆盖链接、按钮、滑杆等控件
        .tint(DS.indigo)
        .environmentObject(aiCoordinator)
        .fullScreenCover(item: $aiCoordinator.presentation) { presentation in
            AIChatContainer(presentation: presentation, coordinator: aiCoordinator)
                .id(presentation.sessionID)
                .environmentObject(aiCoordinator)
        }
        .task {
            ArticleWebViewPrewarmer.shared.warmUpIfNeeded()
            await aiCoordinator.loadIfNeeded()
            authenticationViewModel.restoreIfNeeded()
        }
    }
}

private struct EmptyAICredentialStore: AICredentialStoring {
    func loadAPIKey() throws -> String? { nil }
    func saveAPIKey(_ value: String) throws {}
    func deleteAPIKey() throws {}
}

enum AppEnvironment {
    private static let cache = DiskCacheStore()
    private static let service = makeService()
    private static let repository = DailyRepository(service: service, cacheStore: cache)

    @MainActor
    static func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            repository: repository,
            articleRepository: repository
        )
    }

    @MainActor
    static func makeDetailViewModel(story: StorySummary) -> ArticleDetailViewModel {
        ArticleDetailViewModel(
            story: story,
            repository: repository,
            metricsRepository: repository
        )
    }

    @MainActor
    static func makeStoryMetricsViewModel(storyID: Int) -> StoryMetricsViewModel {
        StoryMetricsViewModel(storyID: storyID, repository: repository)
    }

    @MainActor
    static func makeHotListViewModel() -> HotListViewModel {
        HotListViewModel(repository: repository)
    }

    @MainActor
    static func makeAnswersViewModel(questionID: Int) -> AnswersViewModel {
        AnswersViewModel(repository: repository, questionID: questionID)
    }

    @MainActor
    static func makeAuthenticationViewModel(
        processInfo: ProcessInfo = .processInfo
    ) -> AuthenticationViewModel {
        let service: any AuthenticationServicing
        if processInfo.arguments.contains("-UITestMode") {
            let scenario = AuthMockScenario(value: processInfo.environment["MOCK_AUTH_SCENARIO"])
            service = FixtureAuthenticationService(scenario: scenario)
        } else {
            service = UnavailableAuthenticationService(reason: .missingRequiredValues)
        }
        return AuthenticationViewModel(service: service)
    }

    @MainActor
    static func makeAIChatCoordinator() -> AIChatCoordinator {
        let processInfo = ProcessInfo.processInfo
        if processInfo.arguments.contains("-UITestMode") {
            let suiteName = "DailyReader.UITests.AI"
            let defaults = UserDefaults(suiteName: suiteName) ?? .standard
            defaults.removePersistentDomain(forName: suiteName)
            let builtIns: [AIBuiltInProviderLoader.LoadedProvider]
            if processInfo.environment["MOCK_AI_DEFAULT_SERVICE"] == "1" {
                builtIns = [
                    AIBuiltInProviderLoader.LoadedProvider(
                        profile: AIProviderProfile(
                            id: AIConfigurationStore.defaultProviderID,
                            name: "默认服务",
                            lanes: [
                                AIProviderLaneProfile(
                                    id: "ui-test-lane",
                                    configuration: AIConfiguration(
                                        endpoint: "https://example.com/v1",
                                        model: "ui-test-model",
                                        allowsSearchTools: false
                                    )
                                )
                            ],
                            source: .builtIn
                        ),
                        apiKeys: [:]
                    )
                ]
            } else {
                builtIns = []
            }
            let store = AIConfigurationStore(
                defaults: defaults,
                credentialStore: EmptyAICredentialStore(),
                builtInProviders: builtIns.map(\.profile)
            )
            return AIChatCoordinator(configurationStore: store)
        }

        let builtIns = AIBuiltInProviderLoader().load()
        let store = AIConfigurationStore(builtInProviders: builtIns.map(\.profile))
        try? store.installBuiltInProviders(
            builtIns.map(\.profile),
            apiKeys: builtIns.reduce(into: [:]) { result, loaded in
                result.merge(loaded.apiKeys) { current, _ in current }
            }
        )
        return AIChatCoordinator(configurationStore: store)
    }

    static func makeService() -> DailyServiceProtocol {
        let processInfo = ProcessInfo.processInfo
        if processInfo.arguments.contains("-UITestMode") {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: "DailyReader.readStoryIDs")
            defaults.removeObject(forKey: "DailyReader.hiddenStories")
            defaults.removeObject(forKey: "DailyReader.favoriteStories")
            defaults.removeObject(forKey: "DailyReader.readStories")
            defaults.removeObject(forKey: HomeInformationDensity.storageKey)

            try? FileManager.default.removeItem(
                at: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
                    .first!
                    .appendingPathComponent("DailyReaderCache", isDirectory: true)
            )
            let scenario = processInfo.environment["MOCK_SCENARIO"] ?? "latest_success"
            return LocalFixtureDailyService(scenario: scenario)
        }
        return ZhihuDailyService()
    }
}
