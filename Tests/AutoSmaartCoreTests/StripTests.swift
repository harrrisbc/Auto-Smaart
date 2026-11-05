import XCTest
@testable import AutoSmaartCore

final class StripTests: XCTestCase {
    func testIndexRangesMatchTheSpec() {
        XCTAssertEqual(stripIndexRange(.inputChannel), 1...72)
        XCTAssertEqual(stripIndexRange(.groupBus), 1...24)
        XCTAssertEqual(stripIndexRange(.auxBus), 1...24)
        XCTAssertEqual(stripIndexRange(.matrixBus), 1...12)
    }

    func testWireMinus150IsMinusInfinity() {
        XCTAssertEqual(faderLevel(fromWire: -150), .minusInfinity)
        XCTAssertEqual(faderLevel(fromWire: -149.5), .decibels(-149.5))
        XCTAssertEqual(faderLevel(fromWire: 0), .decibels(0))
        XCTAssertEqual(faderLevel(fromWire: 10), .decibels(10))
        XCTAssertEqual(faderWire(from: .minusInfinity), -150)
        XCTAssertEqual(faderWire(from: .decibels(-6)), -6)
    }

    func testRaiseFromMinusInfinityThenHalfDbSteps() {
        let first = raisedFader(.minusInfinity, by: 0.5)
        XCTAssertEqual(first, .decibels(-149.5))
        XCTAssertEqual(raisedFader(.decibels(-20), by: 0.5), .decibels(-19.5))
        XCTAssertEqual(faderDbComparable(.minusInfinity), -Double.infinity)
        XCTAssertEqual(faderDbComparable(.decibels(3.5)), 3.5, accuracy: 1e-12)
    }
}
