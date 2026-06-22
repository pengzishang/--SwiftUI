import Foundation

struct CachedValue<Value> {
    let value: Value
    let cachedAt: Date
}

struct CachedHomeFeed: Codable, Equatable {
    let sections: [DailySection]
    let topStories: [TopStory]
}

protocol CacheStore {
    func saveLatest(_ response: DailyResponse) async
    func loadLatest() async -> CachedValue<DailyResponse>?
    func saveDaily(_ response: DailyResponse) async
    func loadDaily(date: String) async -> CachedValue<DailyResponse>?
    func saveDetail(_ detail: ArticleDetail) async
    func loadDetail(id: Int) async -> CachedValue<ArticleDetail>?
    
    func saveHomeFeed(sections: [DailySection], topStories: [TopStory]) async
    func loadHomeFeed() async -> CachedValue<CachedHomeFeed>?
}
