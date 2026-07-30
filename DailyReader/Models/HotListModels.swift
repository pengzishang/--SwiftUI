import Foundation

// MARK: - Zhihu Hot List Data Models (v1.2)

struct HotListResponse: Codable {
    static let preferredItemCount = 30

    let data: [HotItem]

    init(data: [HotItem]) {
        self.data = Self.reindexedDeduplicated(data)
    }

    init(zhihuHotListResponse: ZhihuHotListResponse) {
        self.init(data: zhihuHotListResponse.data.enumerated().map { index, item in
            HotItem(
                id: index + 1,
                target: HotTarget(
                    id: item.target.id,
                    title: item.target.title,
                    excerpt: item.target.excerpt ?? item.target.title,
                    thumbnail: item.thumbnail,
                    answerCount: item.target.answerCount
                ),
                detailText: item.detailText
            )
        })
    }

    static func supplementalItems(from dailyResponse: DailyResponse) -> [HotItem] {
        dailyResponse.stories.enumerated().map { index, story in
            HotItem(
                id: index + 1,
                target: HotTarget(
                    id: story.id,
                    title: story.title,
                    excerpt: story.hint ?? story.title,
                    thumbnail: story.images.first,
                    url: story.url.flatMap(URL.init(string:))
                ),
                detailText: story.hint ?? "日报精选"
            )
        }
    }

    static func merged(_ items: [HotItem], preferredCount: Int = preferredItemCount) -> HotListResponse {
        let deduplicated = reindexedDeduplicated(items)
        return HotListResponse(data: Array(deduplicated.prefix(max(preferredCount, deduplicated.count))))
    }

    private static func reindexedDeduplicated(_ items: [HotItem]) -> [HotItem] {
        var seenIDs = Set<Int>()
        var nextRank = 1
        var result: [HotItem] = []

        for item in items where seenIDs.insert(item.target.id).inserted {
            result.append(
                HotItem(
                    id: nextRank,
                    target: item.target,
                    detailText: item.detailText
                )
            )
            nextRank += 1
        }

        return result
    }
}

struct HotNewsResponse: Codable {
    let recent: [HotNewsItem]
}

struct HotNewsItem: Codable {
    let newsID: Int
    let thumbnail: String?
    let title: String

    enum CodingKeys: String, CodingKey {
        case newsID = "news_id"
        case thumbnail
        case title
    }
}

struct ZhihuHotListResponse: Codable {
    let data: [ZhihuHotListItem]
}

struct ZhihuHotListItem: Codable {
    let target: ZhihuHotTarget
    let detailText: String
    let children: [ZhihuHotChild]

    var thumbnail: String? {
        children.first { $0.thumbnail?.isEmpty == false }?.thumbnail
    }

    enum CodingKeys: String, CodingKey {
        case target
        case detailText = "detail_text"
        case children
    }
}

struct ZhihuHotTarget: Codable {
    let id: Int
    let title: String
    let excerpt: String?
    let answerCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, excerpt
        case answerCount = "answer_count"
    }
}

struct ZhihuHotChild: Codable {
    let thumbnail: String?
}

struct HotItem: Codable, Identifiable {
    let id: Int
    let target: HotTarget
    let detailText: String

    enum CodingKeys: String, CodingKey {
        case id
        case target
        case detailText = "detail_text"
    }

    init(id: Int, target: HotTarget, detailText: String) {
        self.id = id
        self.target = target
        self.detailText = detailText
    }
}

struct HotTarget: Codable, Identifiable {
    let id: Int
    let title: String
    let excerpt: String
    let thumbnail: String?
    let url: URL?
    let answerCount: Int?

    init(id: Int, title: String, excerpt: String, thumbnail: String? = nil, url: URL? = nil, answerCount: Int? = nil) {
        self.id = id
        self.title = title
        self.excerpt = excerpt
        self.thumbnail = thumbnail
        self.url = url
        self.answerCount = answerCount
    }
}

struct AnswersResponse: Codable {
    let data: [AnswerItem]
    let paging: AnswersPaging?

    init(data: [AnswerItem], paging: AnswersPaging? = nil) {
        self.data = data
        self.paging = paging
    }
}

struct AnswersPaging: Codable {
    let isEnd: Bool
    let next: String?

    enum CodingKeys: String, CodingKey {
        case isEnd = "is_end"
        case next
    }
}

struct AnswerItem: Codable, Identifiable {
    let id: Int
    let author: AnswerAuthor
    let content: String
    let excerpt: String
    let voteupCount: Int

    enum CodingKeys: String, CodingKey {
        case id, author, content, excerpt
        case voteupCount = "voteup_count"
    }

    init(id: Int, author: AnswerAuthor, content: String, excerpt: String, voteupCount: Int) {
        self.id = id
        self.author = author
        self.content = content
        self.excerpt = excerpt
        self.voteupCount = voteupCount
    }
}

struct AnswerAuthor: Codable {
    let name: String
    let avatarUrl: String

    enum CodingKeys: String, CodingKey {
        case name
        case avatarUrl = "avatar_url"
    }

    init(name: String, avatarUrl: String) {
        self.name = name
        self.avatarUrl = avatarUrl
    }
}
