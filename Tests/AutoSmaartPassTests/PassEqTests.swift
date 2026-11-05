import XCTest
import AutoSmaartCore
import ConsoleOSC
@testable import AutoSmaartPass

@MainActor
final class PassEqTests: XCTestCase {
    func testEqConfirmWritesOnlyUsedBandsThenRemeasures() throws {
        let loud = MagnitudePoint(hz: 100, db: 6, phase: 0)
        let flat = [MagnitudePoint(hz: 100, db: 0, phase: 0), MagnitudePoint(hz: 10000, db: 0, phase: 0)]
        let link = RecordingLink()
        let (pass, reader, _, _) = makePass(traces: [
            capture(magnitude: [loud], finder: 4),
            capture(magnitude: [loud], finder: 4),
            capture(magnitude: [MagnitudePoint(hz: 100, db: 1, phase: 2)], finder: 4)
        ], link: link)
        try prepare(pass, points: flat)
        pass.readTrace()
        pass.confirmDelay()
        XCTAssertEqual(pass.state.step, .eq)
        XCTAssertEqual(pass.state.bands?.count, 8)
        let beforeEq = link.log.count
        pass.confirmEq()
        let eqLog = Array(link.log.dropFirst(beforeEq))
        let band = try eqAddresses(output: 1, band: 1)
        let band2 = try eqAddresses(output: 1, band: 2)
        // confirmReplace reads every item first, then writes. First 8 entries are the first 8 reads.
        XCTAssertEqual(eqLog.prefix(8).map(\.address), [
            band.freq, band.gain, band.q, band.on,
            band2.freq, band2.gain, band2.q, band2.on
        ])
        XCTAssertTrue(eqLog.prefix(8).allSatisfy { $0.op == "read" })
        XCTAssertEqual(eqLog.first { $0.op == "write" && $0.address == band.on }?.value, .int32(1))
        XCTAssertFalse(eqLog.contains { $0.address.contains("eq_freq_9") || $0.address.contains("Channel_Delay") })
        XCTAssertEqual(pass.state.step, .compare)
        XCTAssertEqual(pass.state.afterCurve?.first?.db, 1)
        XCTAssertEqual(pass.state.beforeCurve?.first?.db, 6)
        XCTAssertEqual(pass.state.outputs[0].lastWrite, "4.0 ms · 8 bands")
        XCTAssertEqual(pass.state.outputs[0].eqSnapshot?.count, 8)
        XCTAssertEqual(reader.traceReads, 3)
    }

    func testZeroBandsSendNothingAndDoNotReplaceTheEQSnapshot() throws {
        let point = MagnitudePoint(hz: 100, db: 0.4, phase: 0)
        let preset = [MagnitudePoint(hz: 100, db: 0, phase: 0), MagnitudePoint(hz: 1000, db: 0, phase: 0)]
        let existing = EqBandSnapshot(index: 3, freq: .float32(250), gain: .float32(-1), q: .float32(2), on: .int32(1))
        let link = RecordingLink()
        let (pass, reader, _, _) = makePass(traces: [
            capture(magnitude: [point], finder: 4),
            capture(magnitude: [point], finder: 4)
        ], link: link)
        try prepare(pass, points: preset)
        pass.readTrace()
        pass.confirmDelay()
        XCTAssertEqual(pass.state.bands, [])
        XCTAssertEqual(pass.state.notice, .noEqNeeded)
        pass.setSeededEQSnapshot([existing])
        let reads = reader.traceReads
        let logCount = link.log.count
        pass.confirmEq()
        XCTAssertEqual(link.log.count, logCount)
        XCTAssertEqual(reader.traceReads, reads)
        XCTAssertEqual(pass.state.step, .compare)
        XCTAssertEqual(pass.state.beforeCurve, pass.state.afterCurve)
        XCTAssertEqual(pass.state.notice, .noEqWritten)
        XCTAssertEqual(pass.state.outputs[0].eqSnapshot, [existing])
        XCTAssertEqual(pass.state.outputs[0].lastWrite, "4.0 ms · no EQ")
    }

    func testEqRemeasureFailureStillOpensCompare() throws {
        let loud = MagnitudePoint(hz: 100, db: 6, phase: 0)
        let flat = [MagnitudePoint(hz: 100, db: 0, phase: 0), MagnitudePoint(hz: 10000, db: 0, phase: 0)]
        let (pass, _, _, _) = makePass(traces: [
            capture(magnitude: [loud], finder: 4),
            capture(magnitude: [loud], finder: 4),
            capture(magnitude: [], finder: nil)
        ])
        try prepare(pass, points: flat)
        pass.readTrace()
        pass.confirmDelay()
        pass.confirmEq()
        XCTAssertEqual(pass.state.step, .compare)
        XCTAssertEqual(pass.state.notice, .couldNotRemeasure)
        XCTAssertEqual(pass.state.beforeCurve?.first?.hz, 100)
        XCTAssertNil(pass.state.afterCurve)
        XCTAssertTrue(pass.state.eqRemeasureFailed)
        XCTAssertNotNil(pass.state.outputs[0].eqSnapshot)
        XCTAssertEqual(pass.state.outputs[0].lastWrite, "4.0 ms · 8 bands")
    }

    func testEmptyHostDoesNotSendEq() throws {
        let loud = MagnitudePoint(hz: 100, db: 6, phase: 0)
        let flat = [MagnitudePoint(hz: 20, db: 0, phase: 0), MagnitudePoint(hz: 20000, db: 0, phase: 0)]
        let (pass, _, link, _) = makePass(traces: [
            capture(magnitude: [loud], finder: 4),
            capture(magnitude: [loud], finder: 4)
        ])
        try prepare(pass, points: flat)
        pass.readTrace()
        pass.confirmDelay()
        let writes = link.log.filter { $0.op == "write" }.count
        pass.setHost("")
        pass.confirmEq()
        XCTAssertEqual(link.log.filter { $0.op == "write" }.count, writes)
        XCTAssertEqual(pass.state.step, .eq)
        XCTAssertEqual(pass.state.notice, .writeFailedKept)
        XCTAssertNil(pass.state.outputs[0].eqSnapshot)
    }

    func testFailedEqWriteKeepsThePreviousSnapshot() throws {
        let loud = MagnitudePoint(hz: 100, db: 6, phase: 0)
        let flat = [MagnitudePoint(hz: 100, db: 0, phase: 0), MagnitudePoint(hz: 10000, db: 0, phase: 0)]
        let link = RecordingLink()
        link.failAddresses = ["/sd/Matrix_Outputs/1/EQ/eq_gain_1"]
        let (pass, _, _, _) = makePass(traces: [
            capture(magnitude: [loud], finder: 4),
            capture(magnitude: [loud], finder: 4)
        ], link: link)
        try prepare(pass, points: flat)
        pass.readTrace()
        pass.confirmDelay()
        let seeded = EqBandSnapshot(index: 1, freq: .float32(80), gain: .float32(1), q: .float32(1), on: .int32(1))
        pass.setSeededEQSnapshot([seeded])
        pass.confirmEq()
        XCTAssertEqual(pass.state.notice, .writeFailedKept)
        XCTAssertEqual(pass.state.step, .eq)
        XCTAssertEqual(pass.state.outputs[0].eqSnapshot, [seeded])
        XCTAssertNil(pass.state.outputs[0].lastWrite)
    }
}
