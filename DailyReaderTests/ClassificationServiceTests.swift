import XCTest
@testable import DailyReader

@MainActor
final class ClassificationServiceTests: XCTestCase {
    private struct StubCredentialStore: AICredentialStoring {
        func loadAPIKey() throws -> String? { nil }
        func saveAPIKey(_ value: String) throws {}
        func deleteAPIKey() throws {}
        func loadAPIKey(providerID: String) throws -> String? { nil }
        func saveAPIKey(_ value: String, providerID: String) throws {}
        func deleteAPIKey(providerID: String) throws {}
    }

    private func makeService() -> ArticleClassificationService {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = AIConfigurationStore(defaults: defaults, credentialStore: StubCredentialStore())
        return ArticleClassificationService(configurationStore: store)
    }

    private func taxonomy() -> CategoryTaxonomy {
        CategoryTaxonomy(categories: [ArticleCategory(id: "tech", name: "科技")], isFrozen: true)
    }

    func testClassifyWithoutConfigurationReturnsLocalFallback() async {
        let service = makeService()
        let result = await service.classify(
            articleID: 1,
            title: "AI 芯片取得新突破",
            text: "关于人工智能芯片的研究",
            taxonomy: taxonomy()
        )
        XCTAssertEqual(result.source, .local)
    }

    func testParseReturnsOtherForOutOfSetCategory() {
        let service = makeService()
        let parsed = service.parse(
            "{\"category\":\"美食\",\"confidence\":0.9}",
            taxonomy: taxonomy(),
            articleID: 1
        )
        XCTAssertEqual(parsed?.categoryID, ArticleCategory.other.id)
    }

    func testParseReturnsMatchedCategoryForInSetName() {
        let service = makeService()
        let parsed = service.parse(
            "{\"category\":\"科技\",\"confidence\":0.9}",
            taxonomy: taxonomy(),
            articleID: 1
        )
        XCTAssertEqual(parsed?.categoryID, "tech")
    }

    func testParseReturnsOtherForLowConfidence() {
        let service = makeService()
        let parsed = service.parse(
            "{\"category\":\"科技\",\"confidence\":0.2}",
            taxonomy: taxonomy(),
            articleID: 1
        )
        XCTAssertEqual(parsed?.categoryID, ArticleCategory.other.id)
    }

    func testLocalFallbackMatchesKeyword() {
        let service = makeService()
        let result = service.localFallback(
            articleID: 1,
            title: "人工智能芯片发布",
            text: "新款手机处理器采用先进半导体技术"
        )
        XCTAssertEqual(result.categoryID, "tech")
    }

    func testLocalFallbackReturnsOtherWithoutMatch() {
        let service = makeService()
        let result = service.localFallback(
            articleID: 1,
            title: "随机标题",
            text: "一些毫不相关的文字内容"
        )
        XCTAssertEqual(result.categoryID, ArticleCategory.other.id)
    }
}
