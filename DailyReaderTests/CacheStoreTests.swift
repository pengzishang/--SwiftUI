import XCTest
@testable import DailyReader

final class CacheStoreTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUp() {
        super.setUp()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        super.tearDown()
    }

    func testSaveAndLoadLatestDailyResponse() async {
        let store = DiskCacheStore(rootURL: temporaryDirectory)

        await store.saveLatest(.fixture)
        let cached = await store.loadLatest()

        XCTAssertEqual(cached?.value, .fixture)
    }

    func testCachePersistsAcrossStoreInstances() async {
        let writer = DiskCacheStore(rootURL: temporaryDirectory)
        await writer.saveLatest(.fixture)
        await writer.saveDetail(.fixture)

        let reader = DiskCacheStore(rootURL: temporaryDirectory)
        let cachedLatest = await reader.loadLatest()
        let cachedDetail = await reader.loadDetail(id: 1)

        XCTAssertEqual(cachedLatest?.value, .fixture)
        XCTAssertEqual(cachedDetail?.value, .fixture)
    }

    func testDailyListCacheKeepsMostRecentThirtyEntries() async {
        let store = DiskCacheStore(rootURL: temporaryDirectory)

        for offset in 0..<31 {
            await store.saveDaily(
                DailyResponse(
                    date: String(format: "202606%02d", offset + 1),
                    stories: [StorySummary(id: offset, title: "日报 \(offset)")]
                )
            )
        }

        let cacheRoot = temporaryDirectory
            .appendingPathComponent("DailyReaderCache", isDirectory: true)
            .appendingPathComponent("daily", isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(at: cacheRoot, includingPropertiesForKeys: nil)) ?? []

        XCTAssertEqual(files.count, 30)
        let prunedOldestDaily = await store.loadDaily(date: "20260601")
        let retainedNewestDaily = await store.loadDaily(date: "20260631")
        XCTAssertNil(prunedOldestDaily)
        XCTAssertNotNil(retainedNewestDaily)
    }

    func testBrokenCacheFileReturnsNilInsteadOfCrashing() async throws {
        let store = DiskCacheStore(rootURL: temporaryDirectory)
        let cacheFile = temporaryDirectory
            .appendingPathComponent("DailyReaderCache", isDirectory: true)
            .appendingPathComponent("latest.json")
        try FileManager.default.createDirectory(at: cacheFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: cacheFile)

        let cached = await store.loadLatest()

        XCTAssertNil(cached)
    }
}
