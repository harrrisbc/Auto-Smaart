import XCTest
@testable import AutoSmaartCore

final class FitTests: XCTestCase {
    private struct Fixture: Decodable { var measurement: [MagnitudePoint]; var preset: [MagnitudePoint] }

    private func load(_ name: String) throws -> Fixture {
        let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: name, withExtension: "json")
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: try XCTUnwrap(url)))
    }

    func testInterpolationUsesNaturalLog() throws {
        let preset = [MagnitudePoint(hz: 100, db: 0, phase: 0), MagnitudePoint(hz: 1000, db: -6, phase: 40)]
        let measurement = [MagnitudePoint(hz: 316.22776601683796, db: 0, phase: 0)]
        let result = fitEq(measurement: measurement, preset: preset)
        guard case .bands(let bands) = result else { return XCTFail("\(result)") }
        XCTAssertEqual(try XCTUnwrap(bands.first).gainDb, -3.0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(bands.first).hz, 316.22776601683796, accuracy: 1e-6)
    }

    func testDuplicatePresetFrequencyKeepsTheFirstPoint() {
        let preset = [
            MagnitudePoint(hz: 100, db: 0, phase: 0),
            MagnitudePoint(hz: 100, db: 5, phase: 0),
            MagnitudePoint(hz: 1000, db: 0, phase: 0)
        ]
        let measurement = [MagnitudePoint(hz: 100, db: 0.2, phase: 0)]
        XCTAssertEqual(fitEq(measurement: measurement, preset: preset), .bands([]))
    }

    func testAbsoluteDeviationAtOrBelowOneProducesZeroBands() throws {
        let fixture = try load("flat-within-1db")
        XCTAssertEqual(fitEq(measurement: fixture.measurement, preset: fixture.preset), .bands([]))
        let justOver = [MagnitudePoint(hz: 100, db: 1.04, phase: 0)]
        let preset = [MagnitudePoint(hz: 100, db: 0, phase: 0), MagnitudePoint(hz: 1000, db: 0, phase: 0)]
        guard case .bands(let bands) = fitEq(measurement: justOver, preset: preset) else { return XCTFail("expected bands") }
        XCTAssertEqual(try XCTUnwrap(bands.first).gainDb, -1.0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(bands.first).q, 4.0, accuracy: 1e-9)
    }

    func testNeedsEqMatchesFrequencyGainAndQ() throws {
        let fixture = try load("needs-eq")
        guard case .bands(let bands) = fitEq(measurement: fixture.measurement, preset: fixture.preset) else {
            return XCTFail("expected bands")
        }
        XCTAssertEqual(bands.count, 8)
        XCTAssertEqual(bands[0].index, 1)
        XCTAssertEqual(bands[0].hz, 100, accuracy: 1e-9)
        XCTAssertEqual(bands[0].gainDb, -6.0, accuracy: 1e-9)
        XCTAssertEqual(bands[0].q, 4.0, accuracy: 1e-9)
        XCTAssertEqual(bands[1].hz, 100, accuracy: 1e-9)
        XCTAssertEqual(bands[1].gainDb, -12.0, accuracy: 1e-9)
        XCTAssertEqual(bands[1].q, 4.0, accuracy: 1e-9)
        XCTAssertEqual(bands[2].gainDb, -18.0, accuracy: 1e-9)
        XCTAssertEqual(bands[7].gainDb, -18.0, accuracy: 1e-9)
        XCTAssertEqual(bands[7].index, 8)
    }

    func testTieGoesToTheLowerFrequencyAndLobeSetsQ() {
        let measurement = [
            MagnitudePoint(hz: 800, db: -3, phase: 1),
            MagnitudePoint(hz: 200, db: 3, phase: 2)
        ]
        let preset = [MagnitudePoint(hz: 100, db: 0, phase: 0), MagnitudePoint(hz: 1000, db: 0, phase: 0)]
        guard case .bands(let bands) = fitEq(measurement: measurement, preset: preset) else { return XCTFail("expected bands") }
        XCTAssertEqual(bands[0].hz, 200, accuracy: 1e-9)
        XCTAssertEqual(bands[0].gainDb, -3.0, accuracy: 1e-9)
        XCTAssertEqual(bands[0].q, 0.67, accuracy: 1e-9)
        XCTAssertEqual(bands.count, 8)
    }

    func testPhaseDoesNotChangeTheBands() throws {
        let fixture = try load("needs-eq")
        let other = fixture.measurement.map { MagnitudePoint(hz: $0.hz, db: $0.db, phase: 123) }
        XCTAssertEqual(fitEq(measurement: fixture.measurement, preset: fixture.preset), fitEq(measurement: other, preset: fixture.preset))
    }

    func testSameInputsProduceTheSameBands() throws {
        let fixture = try load("needs-eq")
        XCTAssertEqual(
            fitEq(measurement: fixture.measurement, preset: fixture.preset),
            fitEq(measurement: fixture.measurement, preset: fixture.preset)
        )
    }

    func testNoOverlapAndOutOfBandBins() throws {
        let missing = try load("no-overlap")
        XCTAssertEqual(fitEq(measurement: missing.measurement, preset: missing.preset), .noOverlap)
        let measurement = [MagnitudePoint(hz: 19.999, db: 12, phase: 0), MagnitudePoint(hz: 20, db: 0.2, phase: 0)]
        let preset = [MagnitudePoint(hz: 10, db: 0, phase: 0), MagnitudePoint(hz: 20000, db: 0, phase: 0)]
        XCTAssertEqual(fitEq(measurement: measurement, preset: preset), .bands([]))
    }

    func testSummedResponseMatchesTheBandAtItsCenter() {
        let band = EqBand(index: 1, hz: 100, gainDb: -6, q: 4)
        let curve = summedEqResponse(bands: [band], at: [100])
        XCTAssertEqual(curve.first?.db, -6, accuracy: 1e-9)
        XCTAssertTrue(summedEqResponse(bands: [], samples: 32).isEmpty)
        XCTAssertEqual(summedEqResponse(bands: [band]).count, 128)
    }

    func testPeakingCenterUsesThe48kModel() {
        XCTAssertEqual(peakingMagnitudeDb(binHz: 100, centerHz: 100, gainDb: 6, q: 4), 6, accuracy: 1e-9)
        XCTAssertEqual(peakingMagnitudeDb(binHz: 200, centerHz: 100, gainDb: 6, q: 4), 0.1742005174966169, accuracy: 1e-9)
    }

    func testFrequencyLabels() {
        XCTAssertEqual(formatFrequency(80.4), "80 Hz")
        XCTAssertEqual(formatFrequency(80.5), "81 Hz")
        XCTAssertEqual(formatFrequency(999.5), "1000 Hz")
        XCTAssertEqual(formatFrequency(1000), "1.00 kHz")
        XCTAssertEqual(formatFrequency(3150), "3.15 kHz")
    }

    func testFitSourceHasNoRandomness() throws {
        let source = try String(contentsOfFile: "Sources/AutoSmaartCore/Fit.swift")
        XCTAssertFalse(source.contains("random"))
        XCTAssertFalse(source.contains("Double.random"))
        XCTAssertTrue(source.contains("48000"))
    }
}
