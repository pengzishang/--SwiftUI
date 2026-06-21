import Foundation

actor DiskCacheStore: CacheStore {
    private let fileManager: FileManager
    private let rootURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default, rootURL: URL? = nil) {
        self.fileManager = fileManager
        let baseURL = rootURL ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.rootURL = baseURL.appendingPathComponent("DailyReaderCache", isDirectory: true)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func saveLatest(_ response: DailyResponse) async {
        await write(CacheEnvelope(value: response), to: latestURL)
        await saveDaily(response)
    }

    func loadLatest() async -> CachedValue<DailyResponse>? {
        await read(from: latestURL)
    }

    func saveDaily(_ response: DailyResponse) async {
        guard !response.date.isEmpty else { return }
        await write(CacheEnvelope(value: response), to: dailyURL(for: response.date))
        await pruneDailyLists()
    }

    func loadDaily(date: String) async -> CachedValue<DailyResponse>? {
        await read(from: dailyURL(for: date))
    }

    func saveDetail(_ detail: ArticleDetail) async {
        await write(CacheEnvelope(value: detail), to: detailURL(for: detail.id))
    }

    func loadDetail(id: Int) async -> CachedValue<ArticleDetail>? {
        await read(from: detailURL(for: id))
    }

    private var latestURL: URL {
        rootURL.appendingPathComponent("latest.json")
    }

    private var dailyRootURL: URL {
        rootURL.appendingPathComponent("daily", isDirectory: true)
    }

    private var detailRootURL: URL {
        rootURL.appendingPathComponent("detail", isDirectory: true)
    }

    private func dailyURL(for date: String) -> URL {
        dailyRootURL.appendingPathComponent("\(date).json")
    }

    private func detailURL(for id: Int) -> URL {
        detailRootURL.appendingPathComponent("\(id).json")
    }

    private func write<Value: Codable>(_ envelope: CacheEnvelope<Value>, to url: URL) async {
        do {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try encoder.encode(envelope)
            try data.write(to: url, options: [.atomic])
        } catch {
            return
        }
    }

    private func read<Value: Codable>(from url: URL) async -> CachedValue<Value>? {
        do {
            let data = try Data(contentsOf: url)
            let envelope = try decoder.decode(CacheEnvelope<Value>.self, from: data)
            return CachedValue(value: envelope.value, cachedAt: envelope.cachedAt)
        } catch {
            return nil
        }
    }

    private func pruneDailyLists() async {
        do {
            let urls = try fileManager.contentsOfDirectory(
                at: dailyRootURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            let sorted = urls.sorted { lhs, rhs in
                businessDate(from: lhs) > businessDate(from: rhs)
            }
            for url in sorted.dropFirst(CachePolicy.retainedDailyListCount) {
                try? fileManager.removeItem(at: url)
            }
        } catch {
            return
        }
    }

    private func businessDate(from url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }
}

private struct CacheEnvelope<Value: Codable>: Codable {
    let cachedAt: Date
    let value: Value

    init(value: Value, cachedAt: Date = Date()) {
        self.cachedAt = cachedAt
        self.value = value
    }
}
