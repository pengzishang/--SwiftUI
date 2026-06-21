import Foundation

struct StorySummary: Identifiable, Codable, Equatable, Hashable {
    let id: Int
    let title: String
    let images: [String]
    let hint: String?
    let url: String?

    init(id: Int, title: String, images: [String] = [], hint: String? = nil, url: String? = nil) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.images = images
        self.hint = hint
        self.url = url
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case images
        case hint
        case url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decodeFlexibleInt(forKey: .id)
        let title = (try? container.decode(String.self, forKey: .title))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !title.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .title, in: container, debugDescription: "Story title is required")
        }

        self.id = id
        self.title = title
        self.images = (try? container.decode([String].self, forKey: .images)) ?? []
        self.hint = try? container.decode(String.self, forKey: .hint)
        self.url = try? container.decode(String.self, forKey: .url)
    }
}
