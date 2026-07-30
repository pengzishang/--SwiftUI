import Foundation

@MainActor
final class AnswersViewModel: ObservableObject {
    @Published private(set) var phase: AnswersPhase = .loading
    private let repository: AnswersRepositoryProtocol
    private let questionID: Int

    init(repository: AnswersRepositoryProtocol, questionID: Int) {
        self.repository = repository
        self.questionID = questionID
    }

    func load() async {
        phase = .loading
        do {
            let response = try await repository.fetchAnswers(questionID: questionID)
            phase = response.data.isEmpty ? .empty : .loaded(response.data)
        } catch APIError.httpStatus(403) {
            phase = .restricted
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
