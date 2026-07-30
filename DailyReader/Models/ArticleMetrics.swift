import Foundation

struct DailyStoryMetrics: Codable, Equatable {
    let popularity: Int?
    let comments: Int?
    let longComments: Int?
    let shortComments: Int?

    enum CodingKeys: String, CodingKey {
        case popularity
        case comments
        case longComments = "long_comments"
        case shortComments = "short_comments"
    }

    init(
        popularity: Int?,
        comments: Int?,
        longComments: Int? = nil,
        shortComments: Int? = nil
    ) {
        self.popularity = popularity
        self.comments = comments
        self.longComments = longComments
        self.shortComments = shortComments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        popularity = try? container.decodeFlexibleInt(forKey: .popularity)
        comments = try? container.decodeFlexibleInt(forKey: .comments)
        longComments = try? container.decodeFlexibleInt(forKey: .longComments)
        shortComments = try? container.decodeFlexibleInt(forKey: .shortComments)
    }

    var hasVisibleValues: Bool {
        popularity != nil || comments != nil
    }
}

struct OriginalAnswerMetrics: Codable, Equatable {
    let id: Int?
    let voteupCount: Int?
    let commentCount: Int?
    let favoriteListCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case voteupCount = "voteup_count"
        case commentCount = "comment_count"
        case favoriteListCount = "favlists_count"
    }

    init(
        id: Int? = nil,
        voteupCount: Int?,
        commentCount: Int?,
        favoriteListCount: Int?
    ) {
        self.id = id
        self.voteupCount = voteupCount
        self.commentCount = commentCount
        self.favoriteListCount = favoriteListCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try? container.decodeFlexibleInt(forKey: .id)
        voteupCount = try? container.decodeFlexibleInt(forKey: .voteupCount)
        commentCount = try? container.decodeFlexibleInt(forKey: .commentCount)
        favoriteListCount = try? container.decodeFlexibleInt(forKey: .favoriteListCount)
    }

    var hasVisibleValues: Bool {
        voteupCount != nil || commentCount != nil || favoriteListCount != nil
    }
}

enum OriginalAnswerReferenceParser {
    private static let answerPattern = #"https?://(?:www\.)?zhihu\.com/question/\d+/answer/(\d+)"#

    static func uniqueAnswerID(in html: String?) -> Int? {
        guard let html, !html.isEmpty,
              let expression = try? NSRegularExpression(pattern: answerPattern, options: [.caseInsensitive])
        else {
            return nil
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let answerIDs = Set(expression.matches(in: html, range: range).compactMap { match -> Int? in
            guard match.numberOfRanges > 1,
                  let answerRange = Range(match.range(at: 1), in: html)
            else {
                return nil
            }
            return Int(html[answerRange])
        })

        guard answerIDs.count == 1 else { return nil }
        return answerIDs.first
    }
}
