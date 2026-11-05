import XCTest
@testable import AutoSmaartCore

final class NotchTableTests: XCTestCase {
    func testNewBandUsesLowestIndexAtMinus3AndQ16() {
        let decision = decideNotch(peakHz: 1000, bands: [])
        guard case .write(let band) = decision else { return XCTFail("\(decision)") }
        XCTAssertEqual(band.index, 1)
        XCTAssertEqual(band.hz, 1000, accuracy: 1e-12)
        XCTAssertEqual(band.gainDb, -3.0, accuracy: 1e-12)
        XCTAssertEqual(band.q, 16.0, accuracy: 1e-12)
    }

    func testMatchWithin50CentsDeepensSameBand() {
        let existing = [EqBand(index: 1, hz: 1000, gainDb: -3.0, q: 16.0)]
        // 29 Hz at 1 kHz is about 50 cents; 28 Hz is inside.
        let decision = decideNotch(peakHz: 1016, bands: existing)
        guard case .deepen(let band) = decision else { return XCTFail("\(decision)") }
        XCTAssertEqual(band.index, 1)
        XCTAssertEqual(band.hz, 1000, accuracy: 1e-12)
        XCTAssertEqual(band.gainDb, -6.0, accuracy: 1e-12)
        XCTAssertEqual(band.q, 16.0, accuracy: 1e-12)
        XCTAssertLessThanOrEqual(centsDistance(1016, 1000), 50)
    }

    func testMoreThan50CentsOpensNextBand() {
        let existing = [EqBand(index: 1, hz: 1000, gainDb: -3.0, q: 16.0)]
        let decision = decideNotch(peakHz: 1200, bands: existing)
        guard case .write(let band) = decision else { return XCTFail("\(decision)") }
        XCTAssertEqual(band.index, 2)
        XCTAssertEqual(band.hz, 1200, accuracy: 1e-12)
        XCTAssertGreaterThan(centsDistance(1200, 1000), 50)
    }

    func testClosestCentsWinsAndTieUsesLowerIndex() {
        // Equal cents either side of 1000 (linear ±10 Hz is NOT equal in cents).
        let lowHz = 1000 * pow(2.0, -17.0 / 1200.0)
        let highHz = 1000 * pow(2.0, 17.0 / 1200.0)
        let bands = [
            EqBand(index: 1, hz: lowHz, gainDb: -3.0, q: 16.0),
            EqBand(index: 2, hz: highHz, gainDb: -3.0, q: 16.0)
        ]
        let decision = decideNotch(peakHz: 1000, bands: bands)
        guard case .deepen(let band) = decision else { return XCTFail("\(decision)") }
        XCTAssertEqual(band.index, 1)
        XCTAssertEqual(centsDistance(1000, lowHz), centsDistance(1000, highHz), accuracy: 1e-9)
    }

    func testEightBandsUnmatchedIsBandCap() {
        let bands = (1...8).map { EqBand(index: $0, hz: Double($0) * 200, gainDb: -3.0, q: 16.0) }
        XCTAssertEqual(decideNotch(peakHz: 4500, bands: bands), .bandCap)
    }

    func testDeepenAllowedWhenEightBandsInUse() {
        var bands = (1...8).map { EqBand(index: $0, hz: Double($0) * 200, gainDb: -3.0, q: 16.0) }
        bands[3] = EqBand(index: 4, hz: 1000, gainDb: -9.0, q: 16.0)
        guard case .deepen(let band) = decideNotch(peakHz: 1005, bands: bands) else {
            return XCTFail("expected deepen")
        }
        XCTAssertEqual(band.index, 4)
        XCTAssertEqual(band.gainDb, -12.0, accuracy: 1e-12)
    }

    func testFloorAtMinus18() {
        let bands = [EqBand(index: 1, hz: 1000, gainDb: -18.0, q: 16.0)]
        guard case .floorReached(let band) = decideNotch(peakHz: 1000, bands: bands) else {
            return XCTFail("expected floor")
        }
        XCTAssertEqual(band.gainDb, -18.0, accuracy: 1e-12)
        let almost = [EqBand(index: 1, hz: 1000, gainDb: -16.0, q: 16.0)]
        guard case .deepen(let deepened) = decideNotch(peakHz: 1000, bands: almost) else {
            return XCTFail("expected deepen to floor")
        }
        XCTAssertEqual(deepened.gainDb, -18.0, accuracy: 1e-12)
        let over = [EqBand(index: 1, hz: 1000, gainDb: -17.0, q: 16.0)]
        // -17 + -3 = -20 → clamp decision is floor at -18 with deepen? Spec: deepen by -3; stop deepening when stored gain would go below -18. Floor is -18.
        // From -17, adding -3 would go to -20, so floor at -18.0 and treat as deepen to floor still as deepen with -18, or floorReached?
        // Spec: "Stop deepening when the stored gain would go below −18.0 dB. The floor is −18.0 dB."
        // "If a matched band is already at −18.0 dB, leave gain unchanged ... show Notch floor reached."
        // So from -17: deepen to -18 (allowed). From -18: floorReached.
        XCTAssertEqual(decideNotch(peakHz: 1000, bands: over), .deepen(EqBand(index: 1, hz: 1000, gainDb: -18.0, q: 16.0)))
    }

    func testSkipsUsedIndexesWhenOpeningNewBand() {
        let bands = [EqBand(index: 1, hz: 200, gainDb: -3, q: 16), EqBand(index: 3, hz: 400, gainDb: -3, q: 16)]
        guard case .write(let band) = decideNotch(peakHz: 3000, bands: bands) else { return XCTFail("write") }
        XCTAssertEqual(band.index, 2)
    }
}
