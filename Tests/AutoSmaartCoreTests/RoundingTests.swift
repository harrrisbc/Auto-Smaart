import XCTest
@testable import AutoSmaartCore

final class RoundingTests: XCTestCase {
    func testHalfAwayFromZero() {
        XCTAssertEqual(roundHalfAwayFromZero(12.35, places: 1), 12.4, accuracy: 1e-9)
        XCTAssertEqual(roundHalfAwayFromZero(12.34, places: 1), 12.3, accuracy: 1e-9)
        XCTAssertEqual(roundHalfAwayFromZero(-1.25, places: 1), -1.3, accuracy: 1e-9)
        XCTAssertEqual(roundHalfAwayFromZero(0.05, places: 1), 0.1, accuracy: 1e-9)
        XCTAssertEqual(roundHalfAwayFromZero(-0.05, places: 1), -0.1, accuracy: 1e-9)
        XCTAssertEqual(roundHalfAwayFromZero(80.5, places: 0), 81, accuracy: 1e-9)
        XCTAssertEqual(roundHalfAwayFromZero(80.4, places: 0), 80, accuracy: 1e-9)
        XCTAssertEqual(roundHalfAwayFromZero(-1.04, places: 1), -1.0, accuracy: 1e-9)
        XCTAssertEqual(roundHalfAwayFromZero(-1.05, places: 1), -1.1, accuracy: 1e-9)
    }
}
