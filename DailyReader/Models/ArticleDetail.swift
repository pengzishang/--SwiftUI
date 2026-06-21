import Foundation

struct ArticleDetail: Identifiable, Codable, Equatable {
    let id: Int
    let title: String
    let body: String?
    let image: String?
    let images: [String]
    let imageSource: String?
    let shareURL: String?
    let url: String?
    let css: [String]
    let js: [String]

    init(
        id: Int,
        title: String,
        body: String? = nil,
        image: String? = nil,
        images: [String] = [],
        imageSource: String? = nil,
        shareURL: String? = nil,
        url: String? = nil,
        css: [String] = [],
        js: [String] = []
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.image = image
        self.images = images
        self.imageSource = imageSource
        self.shareURL = shareURL
        self.url = url
        self.css = css
        self.js = js
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case image
        case images
        case imageSource = "image_source"
        case shareURL = "share_url"
        case url
        case css
        case js
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decodeFlexibleInt(forKey: .id)) ?? -1
        self.title = (try? container.decode(String.self, forKey: .title)) ?? "未命名文章"
        self.body = try? container.decode(String.self, forKey: .body)
        self.image = try? container.decode(String.self, forKey: .image)
        self.images = (try? container.decode([String].self, forKey: .images)) ?? []
        self.imageSource = try? container.decode(String.self, forKey: .imageSource)
        self.shareURL = try? container.decode(String.self, forKey: .shareURL)
        self.url = try? container.decode(String.self, forKey: .url)
        self.css = (try? container.decode([String].self, forKey: .css)) ?? []
        self.js = (try? container.decode([String].self, forKey: .js)) ?? []
    }
}
