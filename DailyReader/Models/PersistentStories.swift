import Foundation

struct HiddenStory: Codable, Equatable, Identifiable {
    var id: Int { story.id }
    let date: String
    let story: StorySummary
}

struct FavoriteStory: Codable, Equatable, Identifiable {
    var id: Int { story.id }
    let date: String
    let story: StorySummary
}

struct ReadStory: Codable, Equatable, Identifiable {
    var id: Int { story.id }
    let date: String
    let story: StorySummary
    let readAt: Date

    init(date: String, story: StorySummary, readAt: Date = Date()) {
        self.date = date
        self.story = story
        self.readAt = readAt
    }

    enum CodingKeys: String, CodingKey {
        case date, story, readAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.date = try container.decode(String.self, forKey: .date)
        self.story = try container.decode(StorySummary.self, forKey: .story)
        self.readAt = try container.decodeIfPresent(Date.self, forKey: .readAt) ?? Date()
    }
}
