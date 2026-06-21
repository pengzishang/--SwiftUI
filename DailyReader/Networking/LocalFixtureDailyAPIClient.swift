import Foundation

final class LocalFixtureDailyAPIClient: DailyAPIClient {
    private let scenario: String

    init(scenario: String) {
        self.scenario = scenario
    }

    func fetchLatest() async throws -> DailyResponse {
        if scenario == "offline_no_cache" {
            throw APIError.transport("模拟离线")
        }
        if scenario == "latest_empty" {
            return DailyResponse(date: "20260621", stories: [], topStories: [])
        }
        return DailyResponse(
            date: "20260621",
            stories: [
                StorySummary(id: 1001, title: "今天，先读一篇长一点的故事", images: [], hint: "日报阅读器", url: "https://example.com/story/1001"),
                StorySummary(id: 1002, title: "SwiftUI 里的温柔边界", images: [], hint: "设计与工程", url: "https://example.com/story/1002")
            ],
            topStories: [
                TopStory(id: 1001, title: "今天，先读一篇长一点的故事", image: nil, url: "https://example.com/story/1001")
            ]
        )
    }

    func fetchBefore(date: String) async throws -> DailyResponse {
        DailyResponse(
            date: "20260620",
            stories: [
                StorySummary(id: 9001, title: "昨天的好问题", images: [], hint: "历史日报", url: "https://example.com/story/9001")
            ]
        )
    }

    func fetchDetail(id: Int) async throws -> ArticleDetail {
        if scenario == "detail_empty_body" {
            return ArticleDetail(id: id, title: "文章内容暂不可用", body: "", shareURL: nil)
        }
        if scenario == "detail_missing_share" {
            return ArticleDetail(
                id: id,
                title: "无分享链接文章",
                body: "<p>这篇文章用于验证缺失分享链接时不会分享错误内容。</p>",
                shareURL: nil,
                url: nil
            )
        }
        if scenario == "detail_long_body" {
            let paragraphs = (1...40)
                .map { "<p>长正文段落 \($0)：用于验证详情页可以从头到尾完整滚动阅读。</p>" }
                .joined()
            return ArticleDetail(
                id: id,
                title: "长正文阅读验证",
                body: "\(paragraphs)<p>长正文结尾标记</p>",
                shareURL: "https://example.com/story/\(id)"
            )
        }
        return ArticleDetail(
            id: id,
            title: "今天，先读一篇长一点的故事",
            body: "<p>这是一篇用于 UI 测试的日报文章。它不使用官方品牌资产，只验证阅读闭环。</p>",
            image: nil,
            shareURL: "https://example.com/story/\(id)"
        )
    }
}
