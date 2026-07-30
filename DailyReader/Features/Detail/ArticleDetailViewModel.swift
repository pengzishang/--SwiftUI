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
    @Published private(set) var storyMetrics: DailyStoryMetrics?
    @Published private(set) var originalAnswerMetrics: OriginalAnswerMetrics?
    @Published var bannerMessage: String?

    let story: StorySummary
    private let repository: ArticleRepositoryProtocol
    private let metricsRepository: ArticleMetricsRepositoryProtocol?

    init(
        story: StorySummary,
        repository: ArticleRepositoryProtocol,
        metricsRepository: ArticleMetricsRepositoryProtocol? = nil
    ) {
        self.story = story
        self.repository = repository
        self.metricsRepository = metricsRepository
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
        async let detailLoad: Void = reload()
        async let metricsLoad: Void = loadStoryMetrics()
        _ = await (detailLoad, metricsLoad)
    }

    func reload() async {
        phase = .loading
        do {
            let result = try await repository.fetchDetail(id: story.id)
            try Task.checkCancellation()
            phase = .loaded(result.value, result.source)
            bannerMessage = nil
            await loadOriginalAnswerMetrics(from: result.value.body)
        } catch is CancellationError {
            return
        } catch {
            phase = .failed("文章加载失败，请稍后重试")
        }
    }

    private func loadStoryMetrics() async {
        guard let metricsRepository else { return }
        do {
            let value = try await metricsRepository.fetchStoryMetrics(id: story.id)
            try Task.checkCancellation()
            storyMetrics = value.hasVisibleValues ? value : nil
        } catch {
            storyMetrics = nil
        }
    }

    private func loadOriginalAnswerMetrics(from body: String?) async {
        guard let metricsRepository,
              let answerID = OriginalAnswerReferenceParser.uniqueAnswerID(in: body)
        else {
            originalAnswerMetrics = nil
            return
        }

        do {
            let value = try await metricsRepository.fetchAnswerMetrics(answerID: answerID)
            try Task.checkCancellation()
            originalAnswerMetrics = value.hasVisibleValues ? value : nil
        } catch {
            originalAnswerMetrics = nil
        }
    }
}
