import Foundation

struct TopStory: Identifiable, Codable, Equatable, Hashable {
    let id: Int
    let title: String
    let image: String?
    let url: String?

    init(id: Int, title: String, image: String? = nil, url: String? = nil) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.image = image
        self.url = url
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case image
        case url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decodeFlexibleInt(forKey: .id)
        let title = (try? container.decode(String.self, forKey: .title))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !title.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .title, in: container, debugDescription: "Top story title is required")
        }

        self.id = id
        self.title = title
        self.image = try? container.decode(String.self, forKey: .image)
        self.url = try? container.decode(String.self, forKey: .url)
    }
}
