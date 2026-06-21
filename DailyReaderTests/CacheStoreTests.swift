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
