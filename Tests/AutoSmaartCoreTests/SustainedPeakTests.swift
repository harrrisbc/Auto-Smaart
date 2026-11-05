import XCTest
@testable import AutoSmaartCore

final class SustainedPeakTests: XCTestCase {
    private struct Fixture: Decodable { var bins: [MagnitudePoint] }

    private func load(_ name: String) throws -> [MagnitudePoint] {
        let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: name, withExtension: "json")
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: try XCTUnwrap(url))).bins
    }

    func testNarrowLoudBinIsAPeakFrame() throws {
        let bins = try load("rta-narrow-peak-frame")
        let peak = try XCTUnwrap(peakFrame(in: bins))
        XCTAssertEqual(peak.hz, 1000, accuracy: 1e-9)
        XCTAssertEqual(peak.magnitudeDb, -20, accuracy: 1e-9)
    }

    func testBroadbandLobeIsNotAPeakFrame() throws {
        XCTAssertNil(peakFrame(in: try load("rta-broadband-frame")))
    }

    func testBinsOutsideFocusAreIgnored() {
        let bins = [
            MagnitudePoint(hz: 50, db: 0, phase: 0),
            MagnitudePoint(hz: 100, db: -40, phase: 0),
            MagnitudePoint(hz: 1000, db: -40, phase: 0),
            MagnitudePoint(hz: 8000, db: -40, phase: 0),
            MagnitudePoint(hz: 12000, db: 10, phase: 0)
        ]
        XCTAssertNil(peakFrame(in: bins))
    }

    func testEightConsecutiveFramesDeclareSustainedPeak() throws {
        let bins = try load("rta-narrow-peak-frame")
        let detector = SustainedPeakDetector()
        for _ in 0..<7 {
            XCTAssertNil(detector.push(bins))
        }
        let sustained = try XCTUnwrap(detector.push(bins))
        XCTAssertEqual(sustained.hz, 1000, accuracy: 1e-9)
        XCTAssertEqual(sustained.magnitudeDb, -20, accuracy: 1e-9)
    }

    func testFewerThanEightFramesDoNotDeclare() throws {
        let bins = try load("rta-narrow-peak-frame")
        let detector = SustainedPeakDetector()
        for _ in 0..<7 {
            XCTAssertNil(detector.push(bins))
        }
    }

    func testBinIndexChangeResetsTheStreak() throws {
        let a = [
            MagnitudePoint(hz: 100, db: -40, phase: 0),
            MagnitudePoint(hz: 1000, db: -20, phase: 0),
            MagnitudePoint(hz: 8000, db: -40, phase: 0)
        ]
        let b = [
            MagnitudePoint(hz: 100, db: -40, phase: 0),
            MagnitudePoint(hz: 2000, db: -20, phase: 0),
            MagnitudePoint(hz: 8000, db: -40, phase: 0)
        ]
        let detector = SustainedPeakDetector()
        for _ in 0..<7 { XCTAssertNil(detector.push(a)) }
        XCTAssertNil(detector.push(b))
        for _ in 0..<7 { XCTAssertNil(detector.push(a)) }
        XCTAssertNotNil(detector.push(a))
    }

    func testEmptySpectrumIsNotAPeak() {
        XCTAssertNil(peakFrame(in: []))
        XCTAssertNil(SustainedPeakDetector().push([]))
    }

    func testLoudnessTieChoosesLowerFrequency() {
        let bins = [
            MagnitudePoint(hz: 100, db: -40, phase: 0),
            MagnitudePoint(hz: 500, db: -20, phase: 0),
            MagnitudePoint(hz: 2000, db: -20, phase: 0),
            MagnitudePoint(hz: 8000, db: -40, phase: 0)
        ]
        let peak = peakFrame(in: bins)
        XCTAssertEqual(peak?.hz, 500)
    }
}
