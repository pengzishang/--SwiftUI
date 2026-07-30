import Foundation

struct CachedValue<Value> {
    let value: Value
    let cachedAt: Date
}

struct CachedHomeFeed: Codable, Equatable {
    let sections: [DailySection]
    let topStories: [TopStory]
    let historyCursor: String?

    init(
        sections: [DailySection],
        topStories: [TopStory],
        historyCursor: String? = nil
    ) {
        self.sections = sections
        self.topStories = topStories
        self.historyCursor = historyCursor
    }

    private enum CodingKeys: String, CodingKey {
        case sections
        case topStories
        case historyCursor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sections = try container.decode([DailySection].self, forKey: .sections)
        topStories = try container.decode([TopStory].self, forKey: .topStories)
        historyCursor = try container.decodeIfPresent(String.self, forKey: .historyCursor)
    }
}

protocol CacheStore {
    func saveLatest(_ response: DailyResponse) async
    func loadLatest() async -> CachedValue<DailyResponse>?
    func saveDaily(_ response: DailyResponse) async
    func loadDaily(date: String) async -> CachedValue<DailyResponse>?
    func loadDaily(dates: [String]) async -> [String: CachedValue<DailyResponse>]
    func saveDetail(_ detail: ArticleDetail) async
    func loadDetail(id: Int) async -> CachedValue<ArticleDetail>?
    
    func saveHomeFeed(
        sections: [DailySection],
        topStories: [TopStory],
        historyCursor: String?
    ) async
    func loadHomeFeed() async -> CachedValue<CachedHomeFeed>?

    func saveHotList(_ response: HotListResponse) async
    func loadHotList() async -> CachedValue<HotListResponse>?
}
