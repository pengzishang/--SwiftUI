import Foundation

struct DailySection: Identifiable, Equatable, Codable {
    var id: String { date }
    let date: String
    var stories: [StorySummary]
}

struct HomeFeedSnapshot: Equatable {
    var sections: [DailySection]
    var topStories: [TopStory]
    var historyCursor: String?

    init(
        sections: [DailySection],
        topStories: [TopStory],
        historyCursor: String? = nil
    ) {
        self.sections = sections
        self.topStories = topStories
        self.historyCursor = historyCursor ?? sections.last?.date
    }
}

enum HomeFeedEvent {
    case cached(RepositoryValue<HomeFeedSnapshot>)
    case refreshed(RepositoryValue<HomeFeedSnapshot>)
}
