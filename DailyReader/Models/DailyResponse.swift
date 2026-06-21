import Foundation

struct DailyResponse: Codable, Equatable {
    let date: String
    let stories: [StorySummary]
    let topStories: [TopStory]

    init(date: String, stories: [StorySummary], topStories: [TopStory] = []) {
        self.date = date
        self.stories = stories
        self.topStories = topStories
    }

    enum CodingKeys: String, CodingKey {
        case date
        case stories
        case topStories = "top_stories"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.date = (try? container.decode(String.self, forKey: .date)) ?? ""
        self.stories = Self.decodeLossyArray(StorySummary.self, from: container, forKey: .stories)
        self.topStories = Self.decodeLossyArray(TopStory.self, from: container, forKey: .topStories)
    }

    private static func decodeLossyArray<T: Decodable>(
        _ type: T.Type,
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> [T] {
        guard var nested = try? container.nestedUnkeyedContainer(forKey: key) else { return [] }
        var result: [T] = []
        while !nested.isAtEnd {
            if let value = try? nested.decode(T.self) {
                result.append(value)
            } else {
                _ = try? nested.decode(DiscardedDecodable.self)
            }
        }
        return result
    }
}

private struct DiscardedDecodable: Decodable {}
