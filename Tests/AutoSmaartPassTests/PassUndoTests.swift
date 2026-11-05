import XCTest
import AutoSmaartCore
import ConsoleOSC
@testable import AutoSmaartPass

@MainActor
final class PassUndoTests: XCTestCase {
    func testUndoDelayWritesOnlyTheDelaySnapshot() throws {
        let point = MagnitudePoint(hz: 200, db: 0.2, phase: 0)
        let preset = [MagnitudePoint(hz: 200, db: 0, phase: 0), MagnitudePoint(hz: 1000, db: 0, phase: 0)]
        let link = RecordingLink(values: [
            "/sd/Matrix_Outputs/1/Channel_Delay/delay": .float32(0),
            "/sd/Matrix_Outputs/1/Channel_Delay/fine_delay": .float32(7)
        ])
        let (pass, _, _, _) = makePass(traces: [
            capture(magnitude: [point], finder: 4),
            capture(magnitude: [point], finder: 4)
        ], link: link)
        try prepare(pass, points: preset)
        pass.readTrace()
        XCTAssertNil(pass.state.outputs[0].delaySnapshot)
        pass.undoDelay()
        XCTAssertTrue(link.log.isEmpty)
        pass.confirmDelay()
        pass.confirmEq()
        let beforeUndo = link.log.count
        pass.undoDelay()
        let delay = try delayAddresses(output: 1)
        let undo = Array(link.log.dropFirst(beforeUndo))
        XCTAssertEqual(undo.map(\.address), [delay.delay, delay.fineDelay])
        XCTAssertEqual(undo.map(\.value), [.float32(0), .float32(7)])
        XCTAssertEqual(pass.state.outputs[0].delaySnapshot?.fineDelay, .float32(7))
        XCTAssertEqual(pass.state.outputs[0].lastWrite, "4.0 ms · no EQ")
    }

    func testCompareUndoWritesDelayAndOnlySnapshotBands() throws {
        let loud = MagnitudePoint(hz: 200, db: 6, phase: 0)
        let flat = [MagnitudePoint(hz: 200, db: 0, phase: 0), MagnitudePoint(hz: 10000, db: 0, phase: 0)]
        let link = RecordingLink(values: [
            "/sd/Matrix_Outputs/1/Channel_Delay/delay": .float32(1),
            "/sd/Matrix_Outputs/1/Channel_Delay/fine_delay": .float32(1)
        ])
        let (pass, _, _, _) = makePass(traces: [
            capture(magnitude: [loud], finder: 4),
            capture(magnitude: [loud], finder: 4),
            capture(magnitude: [loud], finder: 4)
        ], link: link)
        try prepare(pass, points: flat)
        pass.readTrace()
        pass.confirmDelay()
        pass.confirmEq()
        let lastWrite = pass.state.outputs[0].lastWrite
        let before = link.log.count
        pass.undoLastWrite()
        let undo = Array(link.log.dropFirst(before))
        let delay = try delayAddresses(output: 1)
        XCTAssertEqual(Array(undo.prefix(2).map(\.address)), [delay.delay, delay.fineDelay])
        XCTAssertEqual(undo.prefix(2).map(\.value), [.float32(1), .float32(1)])
        XCTAssertEqual(undo.filter { $0.address.contains("/EQ/") }.count, 4)
        XCTAssertFalse(undo.contains { $0.address.contains("eq_freq_9") })
        XCTAssertEqual(pass.state.outputs[0].lastWrite, lastWrite)
        XCTAssertNotNil(pass.state.outputs[0].eqSnapshot)
    }

    func testUndoFailureDoesNotChangeTheSnapshotOrLastWrite() throws {
        let point = MagnitudePoint(hz: 200, db: 0.2, phase: 0)
        let preset = [MagnitudePoint(hz: 200, db: 0, phase: 0), MagnitudePoint(hz: 1000, db: 0, phase: 0)]
        let link = RecordingLink(values: [
            "/sd/Matrix_Outputs/1/Channel_Delay/delay": .float32(3),
            "/sd/Matrix_Outputs/1/Channel_Delay/fine_delay": .float32(3)
        ])
        let (pass, _, _, _) = makePass(traces: [
            capture(magnitude: [point], finder: 4),
            capture(magnitude: [point], finder: 4)
        ], link: link)
        try prepare(pass, points: preset)
        pass.readTrace()
        pass.confirmDelay()
        pass.confirmEq()
        link.failAddresses = ["/sd/Matrix_Outputs/1/Channel_Delay/fine_delay"]
        pass.undoDelay()
        XCTAssertEqual(pass.state.notice, .writeFailedMismatch)
        XCTAssertEqual(pass.state.outputs[0].delaySnapshot?.delay, .float32(3))
        XCTAssertEqual(pass.state.outputs[0].lastWrite, "4.0 ms · no EQ")
    }
}
