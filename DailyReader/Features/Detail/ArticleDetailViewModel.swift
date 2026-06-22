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
            return nil
        }
        return Self.validShareURL(from: detail.shareURL ?? detail.url)
    }

    var shareTitle: String {
        guard case .loaded(let detail, _) = phase, !detail.title.isEmpty else {
            return story.title
        }
        return detail.title
    }

    var loadedDetailID: Int? {
        guard case .loaded(let detail, _) = phase else { return nil }
        return detail.id
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
        if let cached = await cacheStore.loadDetail(id: story.id) {
            phase = .loaded(cached.value, .cache(cached.cachedAt))
            bannerMessage = nil
            return
        }

        phase = .loading
        do {
            let detail = try await apiClient.fetchDetail(id: story.id)
            await cacheStore.saveDetail(detail)
            phase = .loaded(detail, .network)
            bannerMessage = nil
        } catch {
            phase = .failed("文章加载失败，请稍后重试")
        }
    }
}
