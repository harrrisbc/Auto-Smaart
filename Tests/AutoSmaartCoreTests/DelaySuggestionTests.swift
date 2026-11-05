import XCTest
@testable import AutoSmaartCore

final class DelaySuggestionTests: XCTestCase {
    private func load(_ name: String) throws -> SmaartCapture {
        let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: name, withExtension: "json")
        let data = try Data(contentsOf: try XCTUnwrap(url))
        return try JSONDecoder().decode(SmaartCapture.self, from: data)
    }

    func testFinderWinsWhenImpulseIsAlsoPresent() throws {
        let capture = try load("finder-and-impulse")
        XCTAssertEqual(delaySuggestion(of: capture), .milliseconds(12.35))
        XCTAssertEqual(displayedDelayMs(12.35), 12.4, accuracy: 1e-9)
        XCTAssertEqual(capture.magnitude.first?.phase, 15.0)
    }

    func testMissingFinderUsesEarliestMaximumAbsoluteSample() throws {
        let capture = try load("impulse-only")
        XCTAssertEqual(delaySuggestion(of: capture), .milliseconds(0.0625))
    }

    func testNeitherFinderNorImpulseProducesNoSuggestion() throws {
        let capture = try load("neither")
        XCTAssertEqual(delaySuggestion(of: capture), .none)
        XCTAssertFalse(capture.magnitude.isEmpty)
    }

    func testMissingMagnitudeIsAnEmptyTrace() throws {
        let capture = try load("no-magnitude")
        XCTAssertTrue(capture.magnitude.isEmpty)
    }

    func testEqualAbsolutePeaksChooseTheEarliestIndex() {
        let capture = SmaartCapture(
            magnitude: [MagnitudePoint(hz: 100, db: 0, phase: 0)],
            delayFinderMs: nil,
            impulse: Impulse(sampleRate: 48000, samples: [0.2, -0.5, 0.5])
        )
        XCTAssertEqual(delaySuggestion(of: capture), .milliseconds(1.0 / 48000.0 * 1000.0))
    }

    func testImpulseWithoutSampleRateProducesNoSuggestion() {
        let capture = SmaartCapture(
            magnitude: [MagnitudePoint(hz: 100, db: 0, phase: 0)],
            delayFinderMs: nil,
            impulse: nil
        )
        XCTAssertEqual(delaySuggestion(of: capture), .none)
    }
}
