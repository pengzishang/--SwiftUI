import Foundation

enum ArticleDetailPhase: Equatable {
    case idle
    case loading
    case loaded(ArticleDetail, ContentSource)
    case failed(String)
}

@MainActor
final class ArticleDetailViewModel: ObservableObject {
    @Published private(set) var phase: ArticleDetailPhase = .idle
    @Published var bannerMessage: String?

    let story: StorySummary
    private let apiClient: DailyAPIClient
    private let cacheStore: CacheStore

    init(story: StorySummary, apiClient: DailyAPIClient, cacheStore: CacheStore) {
        self.story = story
        self.apiClient = apiClient
        self.cacheStore = cacheStore
    }

    var shareURL: URL? {
        guard case .loaded(let detail, _) = phase else {
            return Self.validShareURL(from: story.url)
        }
        return Self.validShareURL(from: detail.shareURL ?? detail.url ?? story.url)
    }

    var shareTitle: String {
        guard case .loaded(let detail, _) = phase, !detail.title.isEmpty else {
            return story.title
        }
        return detail.title
    }

    private static func validShareURL(from rawValue: String?) -> URL? {
        guard
            let rawValue,
            let url = URL(string: rawValue),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            url.host?.isEmpty == false
        else {
            return nil
        }
        return url
    }

    func load() async {
        guard phase == .idle else { return }
        await reload()
    }

    func reload() async {
        phase = .loading
        do {
            let detail = try await apiClient.fetchDetail(id: story.id)
            await cacheStore.saveDetail(detail)
            phase = .loaded(detail, .network)
            bannerMessage = nil
        } catch {
            if let cached = await cacheStore.loadDetail(id: story.id) {
                phase = .loaded(cached.value, .cache(cached.cachedAt))
                bannerMessage = "当前离线，正在显示缓存内容"
            } else {
                phase = .failed("文章加载失败，请稍后重试")
            }
        }
    }
}
