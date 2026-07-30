import XCTest
import UIKit
import Kingfisher
@testable import DailyReader

final class ImageCacheServiceTests: XCTestCase {
    private var cache: ImageCache!

    override func setUp() {
        super.setUp()
        cache = ImageCache(name: "ImageCacheServiceTests-\(UUID().uuidString)")
    }

    override func tearDown() {
        let cleared = expectation(description: "Test cache cleared")
        cache.clearCache {
            cleared.fulfill()
        }
        wait(for: [cleared], timeout: 2)
        cache = nil
        super.tearDown()
    }

    func testConfigureAppliesCacheLimitsAndExpiration() {
        ImageCacheService.configure(cache: cache)

        XCTAssertEqual(
            cache.memoryStorage.config.totalCostLimit,
            ImageCacheService.memoryCostLimit
        )
        XCTAssertEqual(cache.diskStorage.config.sizeLimit, ImageCacheService.diskSizeLimit)
        assertExpiration(
            cache.memoryStorage.config.expiration,
            equals: .seconds(ImageCacheService.memoryExpirationSeconds)
        )
        assertExpiration(
            cache.diskStorage.config.expiration,
            equals: .days(ImageCacheService.diskExpirationDays)
        )
    }

    private func assertExpiration(
        _ actual: StorageExpiration,
        equals expected: StorageExpiration,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch (actual, expected) {
        case (.seconds(let actualSeconds), .seconds(let expectedSeconds)):
            XCTAssertEqual(actualSeconds, expectedSeconds, file: file, line: line)
        case (.days(let actualDays), .days(let expectedDays)):
            XCTAssertEqual(actualDays, expectedDays, file: file, line: line)
        default:
            XCTFail("Unexpected expiration configuration", file: file, line: line)
        }
    }

    func testClearAllRemovesMemoryAndDiskEntries() async throws {
        let key = "test-image"
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        let data = try XCTUnwrap(image.pngData())

        try await cache.store(image, original: data, forKey: key, toDisk: true)

        XCTAssertNotEqual(cache.imageCachedType(forKey: key), .none)
        _ = try await ImageCacheService.diskStorageSize(cache: cache)

        await ImageCacheService.clearAll(cache: cache)

        XCTAssertEqual(cache.imageCachedType(forKey: key), .none)
        let diskStorageSize = try await ImageCacheService.diskStorageSize(cache: cache)
        XCTAssertEqual(diskStorageSize, 0)
    }
}
