import XCTest
@testable import DailyReader

final class SettingsTests: XCTestCase {
    func testDefaultFontSizeIsSixteen() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "DailyReader.fontSize")
        
        let savedSize = defaults.double(forKey: "DailyReader.fontSize")
        XCTAssertEqual(savedSize, 0.0)
    }

    func testFontSizePersistence() {
        let defaults = UserDefaults.standard
        defaults.set(20.0, forKey: "DailyReader.fontSize")
        
        let savedSize = defaults.double(forKey: "DailyReader.fontSize")
        XCTAssertEqual(savedSize, 20.0)
        
        defaults.removeObject(forKey: "DailyReader.fontSize")
    }
}
