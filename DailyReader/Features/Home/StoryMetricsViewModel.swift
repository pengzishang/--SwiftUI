import Foundation

@MainActor
final class StoryMetricsViewModel: ObservableObject {
    @Published private(set) var metrics: DailyStoryMetrics?

    private let storyID: Int
    private let repository: ArticleMetricsRepositoryProtocol
    private var hasLoaded = false

    init(storyID: Int, repository: ArticleMetricsRepositoryProtocol) {
        self.storyID = storyID
        self.repository = repository
    }

    func load() async {
        guard !hasLoaded else { return }
        hasLoaded = true

        do {
            let value = try await repository.fetchStoryMetrics(id: storyID)
            try Task.checkCancellation()
            metrics = value.hasVisibleValues ? value : nil
        } catch is CancellationError {
            hasLoaded = false
        } catch {
            metrics = nil
        }
    }
}
