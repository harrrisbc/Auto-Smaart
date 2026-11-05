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
        let preset = [MagnitudePoint(hz: 125, db: 0, phase: 0), MagnitudePoint(hz: 1000, db: -6, phase: 40)]
        let measurement = [MagnitudePoint(hz: 316.22776601683796, db: 0, phase: 0)]
        let result = fitEq(measurement: measurement, preset: preset)
        guard case .bands(let bands) = result else { return XCTFail("\(result)") }
        XCTAssertEqual(try XCTUnwrap(bands.first).gainDb, -2.7, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(bands.first).hz, 316.22776601683796, accuracy: 1e-6)
    }

    func testDuplicatePresetFrequencyKeepsTheFirstPoint() {
        let preset = [
            MagnitudePoint(hz: 200, db: 0, phase: 0),
            MagnitudePoint(hz: 200, db: 5, phase: 0),
            MagnitudePoint(hz: 1000, db: 0, phase: 0)
        ]
        let measurement = [MagnitudePoint(hz: 200, db: 0.2, phase: 0)]
        XCTAssertEqual(fitEq(measurement: measurement, preset: preset), .bands([]))
    }

    func testAbsoluteDeviationAtOrBelowOneProducesZeroBands() throws {
        let fixture = try load("flat-within-1db")
        XCTAssertEqual(fitEq(measurement: fixture.measurement, preset: fixture.preset), .bands([]))
        let justOver = [MagnitudePoint(hz: 200, db: 1.04, phase: 0)]
        let preset = [MagnitudePoint(hz: 200, db: 0, phase: 0), MagnitudePoint(hz: 1000, db: 0, phase: 0)]
        guard case .bands(let bands) = fitEq(measurement: justOver, preset: preset) else { return XCTFail("expected bands") }
        XCTAssertEqual(try XCTUnwrap(bands.first).gainDb, -1.0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(bands.first).q, 4.0, accuracy: 1e-9)
    }

    func testNeedsEqMatchesFrequencyGainAndQ() throws {
        let fixture = try load("needs-eq")
        guard case .bands(let bands) = fitEq(measurement: fixture.measurement, preset: fixture.preset) else {
            return XCTFail("expected bands")
        }
        // One peaking cut clears the +6 dB bin; unused bands stay empty.
        XCTAssertEqual(bands.count, 1)
        XCTAssertEqual(bands[0].index, 1)
        XCTAssertEqual(bands[0].hz, 200, accuracy: 1e-9)
        XCTAssertEqual(bands[0].gainDb, -6.0, accuracy: 1e-9)
        XCTAssertEqual(bands[0].q, 4.0, accuracy: 1e-9)
    }

    func testFitIgnoresBelow125AndTopOctaveWhenNotAShelf() {
        // Mid is not flat (hot at 1 kHz), so this is not a shelf — and the
        // out-of-band spikes must not become peaking bells.
        let measurement = [
            MagnitudePoint(hz: 40, db: 12, phase: 0),
            MagnitudePoint(hz: 63, db: 12, phase: 0),
            MagnitudePoint(hz: 1000, db: 6, phase: 0),
            MagnitudePoint(hz: 2000, db: 0.2, phase: 0),
            MagnitudePoint(hz: 16000, db: 12, phase: 0)
        ]
        let preset = [
            MagnitudePoint(hz: 20, db: 0, phase: 0),
            MagnitudePoint(hz: 20000, db: 0, phase: 0)
        ]
        guard case .bands(let bands) = fitEq(measurement: measurement, preset: preset) else {
            return XCTFail("expected bands")
        }
        XCTAssertFalse(bands.contains { $0.shape == .lowShelf })
        XCTAssertFalse(bands.contains { $0.hz < fitBandLowHz || $0.hz > fitBandHighHz })
    }

    func testMusicLowShelfIsOneShelfNotAKneeSpike() {
        let frequencies: [Double] = [
            20, 25, 31.5, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500,
            800, 1000, 2000, 4000, 8000, 16000
        ]
        let measurement = frequencies.map { MagnitudePoint(hz: $0, db: 0, phase: 0) }
        let music = BuiltInTargets.presets.first { $0.name == "Music" }!.points
        guard case .bands(let bands) = fitEq(measurement: measurement, preset: music) else {
            return XCTFail("expected bands")
        }
        XCTAssertEqual(bands.count, 1)
        XCTAssertEqual(bands[0].shape, .lowShelf)
        XCTAssertGreaterThan(bands[0].gainDb, 1.5)
        XCTAssertLessThan(bands[0].hz, 250)
        XCTAssertFalse(bands.contains { $0.shape == .peaking })
    }

    func testSpeechFlatTraceDoesNotChaseBelow125() {
        let frequencies: [Double] = [
            20, 40, 80, 125, 250, 500, 1000, 2000, 4000, 8000, 16000
        ]
        let measurement = frequencies.map { MagnitudePoint(hz: $0, db: 0, phase: 0) }
        let speech = BuiltInTargets.presets.first { $0.name == "Speech" }!.points
        guard case .bands(let bands) = fitEq(measurement: measurement, preset: speech) else {
            return XCTFail("expected bands")
        }
        // Gentle HF rise vs a flat trace may need peaking in-band; never under 125 Hz.
        XCTAssertFalse(bands.contains { $0.hz < fitBandLowHz })
        XCTAssertFalse(bands.contains { $0.shape == .lowShelf })
        XCTAssertFalse(bands.contains { $0.hz > fitBandHighHz })
    }

    func testInBandSpeechGapStillFits() {
        let frequencies: [Double] = [
            125, 160, 200, 250, 315, 400, 500, 800, 1000, 2000, 4000, 8000
        ]
        let measurement = frequencies.map { hz -> MagnitudePoint in
            MagnitudePoint(hz: hz, db: hz == 1000 ? 4 : 0, phase: 0)
        }
        let speech = BuiltInTargets.presets.first { $0.name == "Speech" }!.points
        guard case .bands(let bands) = fitEq(measurement: measurement, preset: speech) else {
            return XCTFail("expected bands")
        }
        XCTAssertFalse(bands.isEmpty)
        XCTAssertEqual(bands[0].shape, .peaking)
        XCTAssertEqual(bands[0].hz, 1000, accuracy: 1)
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
        // Opposite-sign bins are separate lobes, so each single-bin lobe uses Q 4.
        XCTAssertEqual(bands[0].q, 4.0, accuracy: 1e-9)
        // Separate dip at 800 Hz still gets its own band; no stacking beyond that.
        XCTAssertEqual(bands.count, 2)
        XCTAssertEqual(bands[1].hz, 800, accuracy: 1e-9)
        XCTAssertEqual(bands[1].gainDb, 3.0, accuracy: 1e-9)
    }

    func testBroadLowRiseUsesOneBand() {
        // Trace sits above a flat target only in the lows, then flat — one broad cut.
        let frequencies: [Double] = [
            40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 800, 1000, 2000, 4000, 8000
        ]
        let measurement = frequencies.map { hz -> MagnitudePoint in
            let db: Double
            if hz <= 80 {
                db = 4
            } else if hz < 250 {
                db = 4 * (1 - log(hz / 80) / log(250.0 / 80.0))
            } else {
                db = 0
            }
            return MagnitudePoint(hz: hz, db: db, phase: 0)
        }
        let preset = [
            MagnitudePoint(hz: 20, db: 0, phase: 0),
            MagnitudePoint(hz: 20000, db: 0, phase: 0)
        ]
        guard case .bands(let bands) = fitEq(measurement: measurement, preset: preset) else {
            return XCTFail("expected bands")
        }
        XCTAssertEqual(bands.count, 1, "broad low-only rise must not burn all 8 bands")
        XCTAssertEqual(bands[0].shape, .lowShelf, "a shelf-shaped low rise is one low shelf, not a knee spike")
        XCTAssertLessThanOrEqual(bands[0].hz, 250)
        XCTAssertLessThan(bands[0].gainDb, -1)
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
        let outsideFitBand = [
            MagnitudePoint(hz: 40, db: 12, phase: 0),
            MagnitudePoint(hz: 16000, db: 12, phase: 0)
        ]
        let preset = [MagnitudePoint(hz: 10, db: 0, phase: 0), MagnitudePoint(hz: 20000, db: 0, phase: 0)]
        XCTAssertEqual(fitEq(measurement: outsideFitBand, preset: preset), .noOverlap)
        let quietInBand = [MagnitudePoint(hz: 1000, db: 0.2, phase: 0)]
        XCTAssertEqual(fitEq(measurement: quietInBand, preset: preset), .bands([]))
    }

    func testSummedResponseMatchesTheBandAtItsCenter() {
        let band = EqBand(index: 1, hz: 100, gainDb: -6, q: 4)
        let curve = summedEqResponse(bands: [band], at: [100])
        XCTAssertEqual(try XCTUnwrap(curve.first).db, -6, accuracy: 1e-9)
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
