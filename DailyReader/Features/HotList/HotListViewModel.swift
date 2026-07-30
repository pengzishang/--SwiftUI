import Foundation

@MainActor
final class HotListViewModel: ObservableObject {
    @Published private(set) var phase: HotListPhase = .loading
    private let repository: HotListRepositoryProtocol

    init(repository: HotListRepositoryProtocol) {
        self.repository = repository
    }

    func load() async {
        await load(forceRefresh: false)
    }

    func refresh() async {
        await load(forceRefresh: true)
    }

    private func load(forceRefresh: Bool) async {
        phase = .loading
        do {
            let response = try await repository.fetchHotList(forceRefresh: forceRefresh)
            updatePhase(with: response.value)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func updatePhase(with response: HotListResponse) {
        phase = response.data.isEmpty ? .empty : .loaded(response.data)
    }
}
