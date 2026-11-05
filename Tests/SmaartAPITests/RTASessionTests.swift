import XCTest
@testable import SmaartAPI
@testable import AutoSmaartCore

final class RTASessionTests: XCTestCase {
    func testActiveSpectrumReturnsMagnitudeWithoutFindDelay() throws {
        let wire = ScriptedWire(replies: [
            #"{"transferFunctionMeasurements":[],"spectrumMeasurements":[]}"#,
            #"{"spectrumMeasurements":[{"measurementName":"RTA","active":true}],"transferFunctionMeasurements":[]}"#,
            #"{"magnitude":[{"hz":1000,"db":-20},{"hz":2000,"db":-40}]}"#
        ])
        let session = OfficialSmaartSession(wire: wire)
        try session.openSession()
        XCTAssertTrue(try session.hasActiveRTA())
        let bins = try session.readRTA()
        XCTAssertEqual(bins, [
            MagnitudePoint(hz: 1000, db: -20, phase: 0),
            MagnitudePoint(hz: 2000, db: -40, phase: 0)
        ])
        let sent = wire.sent
        XCTAssertEqual(sent.count, 3)
        XCTAssertFalse(sent.joined().contains("findDelay"))
        XCTAssertTrue(sent[1].contains("measurements"))
        XCTAssertTrue(sent[2].contains("RTA"))
    }

    func testNoActiveSpectrumIsNoRTA() throws {
        let wire = ScriptedWire(replies: [
            #"{}"#,
            #"{"spectrumMeasurements":[{"measurementName":"RTA","active":false}],"transferFunctionMeasurements":[{"measurementName":"TF","active":true}]}"#
        ])
        let session = OfficialSmaartSession(wire: wire)
        try session.openSession()
        XCTAssertFalse(try session.hasActiveRTA())
        XCTAssertThrowsError(try session.readRTA()) { error in
            XCTAssertEqual(error as? SmaartReaderError, .noRTA)
        }
    }

    func testEmptyMagnitudeIsNoRTA() throws {
        let wire = ScriptedWire(replies: [
            #"{}"#,
            #"{"spectrumMeasurements":[{"measurementName":"RTA","active":true}]}"#,
            #"{"magnitude":[]}"#
        ])
        let session = OfficialSmaartSession(wire: wire)
        try session.openSession()
        XCTAssertThrowsError(try session.readRTA()) { error in
            XCTAssertEqual(error as? SmaartReaderError, .noRTA)
        }
    }

    func testReadRTABeforeOpenThrowsSessionClosed() {
        let session = OfficialSmaartSession(wire: ScriptedWire(replies: []))
        XCTAssertThrowsError(try session.readRTA()) { error in
            XCTAssertEqual(error as? SmaartReaderError, .sessionClosed)
        }
    }
}
