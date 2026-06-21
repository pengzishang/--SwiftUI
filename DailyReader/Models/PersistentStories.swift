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
}
