import XCTest
import AutoSmaartCore
import ConsoleOSC
@testable import AutoSmaartPass

@MainActor
final class PassDelayTests: XCTestCase {
    func testConfirmSendsTheDisplayedNumberOnBothAddresses() throws {
        let point = MagnitudePoint(hz: 200, db: 0, phase: 0)
        let link = RecordingLink(values: [
            "/sd/Matrix_Outputs/1/Channel_Delay/delay": .float32(1.5),
            "/sd/Matrix_Outputs/1/Channel_Delay/fine_delay": .float32(2.5)
        ])
        let remeasure = capture(magnitude: [point], finder: 1)
        let (pass, _, _, _) = makePass(traces: [capture(magnitude: [point], finder: 12.35), remeasure], link: link)
        try prepare(pass, points: [point])
        pass.readTrace()
        XCTAssertEqual(pass.state.displayedDelayMs, 12.4)
        let writesBefore = link.log.count
        pass.confirmDelay()
        let delay = try delayAddresses(output: 1)
        let writes = link.log.filter { $0.op == "write" }
        XCTAssertEqual(writes.map(\.address), [delay.delay, delay.fineDelay])
        XCTAssertEqual(writes.map(\.value), [.float32(Float(12.4)), .float32(Float(12.4))])
        XCTAssertEqual(pass.state.outputs[0].delaySnapshot?.delay, .float32(1.5))
        XCTAssertEqual(pass.state.outputs[0].delaySnapshot?.fineDelay, .float32(2.5))
        XCTAssertTrue(pass.state.delayWrittenThisPass)
        XCTAssertGreaterThan(link.log.count, writesBefore)
        XCTAssertNil(pass.state.outputs[0].lastWrite)
    }

    func testNegativeSuggestionIsNotClamped() throws {
        let point = MagnitudePoint(hz: 200, db: 0, phase: 0)
        let link = RecordingLink()
        let (pass, _, _, _) = makePass(
            traces: [capture(magnitude: [point], finder: -1.25), capture(magnitude: [point], finder: 0)],
            link: link
        )
        try prepare(pass, points: [point])
        pass.readTrace()
        pass.confirmDelay()
        let writes = link.log.filter { $0.op == "write" }
        XCTAssertEqual(writes.map(\.value), [.float32(Float(-1.3)), .float32(Float(-1.3))])
    }

    func testMatchingPreviousValueStillRequiresConfirm() throws {
        let point = MagnitudePoint(hz: 200, db: 0, phase: 0)
        let (pass, _, link, _) = makePass(
            traces: [capture(magnitude: [point], finder: 12.35), capture(magnitude: [point], finder: 1)],
            link: RecordingLink(values: [
                "/sd/Matrix_Outputs/1/Channel_Delay/delay": .float32(12.4),
                "/sd/Matrix_Outputs/1/Channel_Delay/fine_delay": .float32(12.4)
            ])
        )
        try prepare(pass, points: [point])
        pass.readTrace()
        pass.openRail(.eq)
        XCTAssertEqual(pass.state.step, .delay)
        XCTAssertNil(pass.state.bands)
        pass.confirmDelay()
        XCTAssertEqual(pass.state.step, .eq)
        XCTAssertFalse(link.log.isEmpty)
    }

    func testFailedReadWritesNothingAndKeepsTheSnapshot() throws {
        let point = MagnitudePoint(hz: 200, db: 0, phase: 0)
        let link = RecordingLink()
        link.failAddresses = ["/sd/Matrix_Outputs/1/Channel_Delay/fine_delay"]
        let (pass, reader, _, _) = makePass(traces: [capture(magnitude: [point], finder: 4)], link: link)
        try prepare(pass, points: [point])
        pass.readTrace()
        pass.confirmDelay()
        XCTAssertEqual(pass.state.notice, .writeFailedKept)
        XCTAssertEqual(pass.state.step, .delay)
        XCTAssertNil(pass.state.outputs[0].delaySnapshot)
        XCTAssertFalse(pass.state.delayWrittenThisPass)
        XCTAssertEqual(reader.traceReads, 1)
        XCTAssertTrue(link.log.allSatisfy { $0.op == "read" })
    }

    func testInvalidPortDoesNotSend() throws {
        let point = MagnitudePoint(hz: 200, db: 0, phase: 0)
        let (pass, _, link, _) = makePass(traces: [capture(magnitude: [point], finder: 4)])
        try prepare(pass, points: [point])
        pass.readTrace()
        pass.setPort("abc")
        pass.confirmDelay()
        XCTAssertEqual(pass.state.notice, .writeFailedKept)
        XCTAssertTrue(link.log.isEmpty)
    }

    func testRemeasureFailureStaysOnDelayAndRetryDoesNotWrite() throws {
        let point = MagnitudePoint(hz: 200, db: 6, phase: 0)
        let preset = [MagnitudePoint(hz: 20, db: 0, phase: 0), MagnitudePoint(hz: 20000, db: 0, phase: 0)]
        let (pass, reader, link, _) = makePass(traces: [
            capture(magnitude: [point], finder: 4),
            capture(magnitude: [], finder: 4),
            capture(magnitude: [point], finder: 4)
        ])
        try prepare(pass, points: preset)
        pass.readTrace()
        pass.confirmDelay()
        XCTAssertEqual(pass.state.notice, .couldNotRemeasure)
        XCTAssertEqual(pass.state.step, .delay)
        XCTAssertTrue(pass.state.delayWrittenThisPass)
        XCTAssertNil(pass.state.bands)
        let writes = link.log.filter { $0.op == "write" }.count
        pass.retryRemeasure()
        XCTAssertEqual(link.log.filter { $0.op == "write" }.count, writes)
        XCTAssertEqual(pass.state.step, .eq)
        XCTAssertEqual(reader.traceReads, 3)
        XCTAssertEqual(pass.state.bands?.first?.hz, 200)
    }

    func testPresetThatDoesNotOverlapStaysOnDelay() throws {
        let first = MagnitudePoint(hz: 200, db: 0, phase: 0)
        let outside = MagnitudePoint(hz: 200, db: 6, phase: 0)
        let preset = [MagnitudePoint(hz: 1000, db: 0, phase: 0), MagnitudePoint(hz: 2000, db: 0, phase: 0)]
        let (pass, _, link, _) = makePass(traces: [
            capture(magnitude: [first], finder: 4),
            capture(magnitude: [outside], finder: 4)
        ])
        try prepare(pass, points: preset)
        pass.readTrace()
        pass.confirmDelay()
        XCTAssertEqual(pass.state.notice, .presetNoOverlap)
        XCTAssertEqual(pass.state.step, .delay)
        XCTAssertNil(pass.state.bands)
        XCTAssertFalse(pass.canOpen(.eq))
        XCTAssertEqual(link.log.filter { $0.op == "write" }.count, 2)
    }
}
