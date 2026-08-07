import XCTest
@testable import DailyReader

final class InterestIndexEngineTests: XCTestCase {
    private func record(
        articleID: Int = 1,
        dwellSeconds: Double = 0,
        maxScrollPercent: Double = 0,
        readCount: Int = 0,
        isFavorited: Bool = false,
        isHidden: Bool = false
    ) -> ReadingInterestRecord {
        ReadingInterestRecord(
            articleID: articleID,
            dwellSeconds: dwellSeconds,
            maxScrollPercent: maxScrollPercent,
            readCount: readCount,
            isFavorited: isFavorited,
            isHidden: isHidden
        )
    }

    private func taxonomy(with categories: [ArticleCategory]) -> CategoryTaxonomy {
        CategoryTaxonomy(categories: categories, isFrozen: true)
    }

    func testHiddenStoryScoresZero() {
        let value = InterestIndexEngine.rawScore(for: record(isHidden: true))
        XCTAssertEqual(value, 0, accuracy: 0.0001)
    }

    func testFullEngagementWithoutFavoriteReachesOne() {
        let value = InterestIndexEngine.rawScore(
            for: record(dwellSeconds: 180, maxScrollPercent: 1, readCount: 5)
        )
        XCTAssertEqual(value, 1.0, accuracy: 0.0001)
    }

    func testFavoriteAddsBonus() {
        let base = InterestIndexEngine.rawScore(
            for: record(dwellSeconds: 180, maxScrollPercent: 1, readCount: 5)
        )
        var favorited = record(dwellSeconds: 180, maxScrollPercent: 1, readCount: 5)
        favorited.isFavorited = true
        let withFavorite = InterestIndexEngine.rawScore(for: favorited)
        XCTAssertEqual(base, 1.0, accuracy: 0.0001)
        XCTAssertEqual(withFavorite, 1.0, accuracy: 0.0001)
        XCTAssertGreaterThanOrEqual(withFavorite, base)
    }

    func testDwellIsNormalizedAndCapped() {
        let half = InterestIndexEngine.rawScore(for: record(dwellSeconds: 90, maxScrollPercent: 0, readCount: 0))
        let full = InterestIndexEngine.rawScore(for: record(dwellSeconds: 400, maxScrollPercent: 0, readCount: 0))
        XCTAssertEqual(half, 0.2, accuracy: 0.0001)
        XCTAssertEqual(full, 0.4, accuracy: 0.0001)
    }

    func testDecayHalvesAfterThirtyDays() {
        let rec = record(lastReadAt: Date())
        let now = rec.lastReadAt.addingTimeInterval(30 * 86_400)
        let factor = InterestIndexEngine.decayFactor(for: rec, now: now)
        XCTAssertEqual(factor, 0.5, accuracy: 0.01)
    }

    func testDecayPreservesRecentReading() {
        let rec = record(lastReadAt: Date())
        let factor = InterestIndexEngine.decayFactor(for: rec, now: rec.lastReadAt)
        XCTAssertEqual(factor, 1.0, accuracy: 0.0001)
    }

    func testCategoryIndexSortsDescendingAndPinsOtherToBottom() {
        let tech = ArticleCategory(id: "tech", name: "科技", order: 0)
        let business = ArticleCategory(id: "business", name: "商业", order: 1)
        let tax = taxonomy(with: [tech, business])

        var classifications: [Int: ArticleClassification] = [:]
        var records: [Int: ReadingInterestRecord] = [:]
        for id in 1...3 {
            classifications[id] = ArticleClassification(articleID: id, categoryID: "tech", confidence: 1, source: .remote)
            records[id] = record(articleID: id, dwellSeconds: 180, maxScrollPercent: 1, readCount: 5)
        }
        classifications[4] = ArticleClassification(articleID: 4, categoryID: "business", confidence: 1, source: .remote)
        records[4] = record(articleID: 4, dwellSeconds: 180, maxScrollPercent: 1, readCount: 5)

        let result = InterestIndexEngine.categoryIndex(
            classifications: classifications,
            records: records,
            taxonomy: tax
        )

        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result.last?.category.isOther == true)
        XCTAssertEqual(result.first?.category.id, "tech")
        XCTAssertEqual(result.first?.score, 1.0, accuracy: 0.0001)
        XCTAssertEqual(result.first?.isLowSample, false)
    }

    func testCategoryIndexFlagsLowSample() {
        let tech = ArticleCategory(id: "tech", name: "科技", order: 0)
        let tax = taxonomy(with: [tech])

        var classifications: [Int: ArticleClassification] = [:]
        var records: [Int: ReadingInterestRecord] = [:]
        classifications[1] = ArticleClassification(articleID: 1, categoryID: "tech", confidence: 1, source: .remote)
        records[1] = record(articleID: 1, dwellSeconds: 180, maxScrollPercent: 1, readCount: 5)

        let result = InterestIndexEngine.categoryIndex(
            classifications: classifications,
            records: records,
            taxonomy: tax
        )

        let techEntry = result.first { $0.category.id == "tech" }
        XCTAssertEqual(techEntry?.memberCount, 1)
        XCTAssertTrue(techEntry?.isLowSample == true)
    }
}
