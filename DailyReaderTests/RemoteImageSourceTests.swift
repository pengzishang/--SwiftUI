import XCTest
@testable import DailyReader

final class RemoteImageSourceTests: XCTestCase {
    func testAcceptsHTTPSURL() {
        XCTAssertEqual(
            RemoteImageSource("https://example.com/image.jpg"),
            .remote(URL(string: "https://example.com/image.jpg")!)
        )
    }

    func testAcceptsHTTPURL() {
        XCTAssertEqual(
            RemoteImageSource("http://example.com/image.jpg"),
            .remote(URL(string: "http://example.com/image.jpg")!)
        )
    }

    func testRejectsEmptyAndUnsupportedURLs() {
        XCTAssertEqual(RemoteImageSource(nil), .invalid)
        XCTAssertEqual(RemoteImageSource("  "), .invalid)
        XCTAssertEqual(RemoteImageSource("not a url"), .invalid)
        XCTAssertEqual(RemoteImageSource("file:///tmp/image.jpg"), .invalid)
    }

    func testDecodesBase64ImageDataURL() {
        let source = RemoteImageSource(
            "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=="
        )

        guard case .dataImage(let data) = source else {
            return XCTFail("Expected a local data image")
        }
        XCTAssertFalse(data.isEmpty)
    }

    func testRejectsInvalidDataURLs() {
        XCTAssertEqual(RemoteImageSource("data:text/plain;base64,SGVsbG8="), .invalid)
        XCTAssertEqual(RemoteImageSource("data:image/png;base64,not-image-data"), .invalid)
        XCTAssertEqual(RemoteImageSource("data:image/png,raw-data"), .invalid)
    }

    func testDuplicateOnlyMatchesEquivalentRemoteURLs() {
        XCTAssertTrue(
            RemoteImageSource.isDuplicate(
                "https://example.com/image.jpg",
                "https://example.com/image.jpg"
            )
        )
        XCTAssertFalse(
            RemoteImageSource.isDuplicate(
                "https://example.com/image.jpg",
                "https://example.com/other.jpg"
            )
        )
        XCTAssertFalse(RemoteImageSource.isDuplicate(nil, nil))
    }
}
