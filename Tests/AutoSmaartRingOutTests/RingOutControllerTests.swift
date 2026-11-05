import XCTest
@testable import AutoSmaartRingOut
@testable import AutoSmaartCore
@testable import ConsoleOSC
@testable import SmaartAPI

final class FakeRTA: SmaartReader {
    var open = false
    var frames: [[MagnitudePoint]] = []
    var hasRTA = true
    var preferredMeasurementName = ""
    func openSession() throws { open = true }
    func closeSession() { open = false }
    func setSignalGeneratorActive(_ active: Bool) throws {
        guard open else { throw SmaartReaderError.sessionClosed }
    }

    func captureTransferFunction(as name: String) throws {
        guard open else { throw SmaartReaderError.sessionClosed }
        _ = name
    }

    var isSessionOpen: Bool { open }
    func readTrace() throws -> SmaartCapture { throw SmaartReaderError.noTrace }
    func readTargetCurve() throws -> [MagnitudePoint] { throw SmaartReaderError.noTarget }
    func hasActiveRTA() throws -> Bool {
        guard open else { throw SmaartReaderError.sessionClosed }
        return hasRTA
    }
    func readRTA() throws -> [MagnitudePoint] {
        guard open else { throw SmaartReaderError.sessionClosed }
        guard hasRTA else { throw SmaartReaderError.noRTA }
        guard !frames.isEmpty else { throw SmaartReaderError.noRTA }
        return frames.removeFirst()
    }
}

final class RingOutControllerTests: XCTestCase {
    private func narrowFrame(hz: Double = 1000, db: Double = -20) -> [MagnitudePoint] {
        [
            MagnitudePoint(hz: 100, db: -40, phase: 0),
            MagnitudePoint(hz: hz, db: db, phase: 0),
            MagnitudePoint(hz: 8000, db: -40, phase: 0)
        ]
    }

    private func makeController(startDb: Float = -20) throws -> (RingOutController, FakeRTA, MemoryLink) {
        let fader = try faderAddress(kind: .inputChannel, index: 1)
        let link = MemoryLink(values: [fader: .float32(startDb)])
        let smaart = FakeRTA()
        try smaart.openSession()
        let controller = RingOutController(
            smaart: smaart,
            linkFactory: { _, _ in link }
        )
        controller.updateHost("127.0.0.1")
        controller.updatePort("9000")
        controller.selectFader(kind: .inputChannel, index: 1)
        controller.selectEQ(kind: .inputChannel, index: 1)
        return (controller, smaart, link)
    }

    func testStartRecordsFaderBeforeRaise() throws {
        let (controller, smaart, link) = try makeController(startDb: -12)
        smaart.frames = Array(repeating: narrowFrame(), count: 1)
        controller.start()
        XCTAssertEqual(controller.state.startFader, .decibels(-12))
        XCTAssertEqual(controller.state.phase, .running)
        XCTAssertEqual(link.log.filter { $0.0 == "write" }.count, 0)
    }

    func testRaiseWritesOnlyFaderUntilPeakThenMinusInfinityThenEQ() throws {
        let (controller, smaart, link) = try makeController(startDb: -6)
        // No peaks for a few ticks, then eight peak frames.
        smaart.frames = Array(repeating: [
            MagnitudePoint(hz: 100, db: -40, phase: 0),
            MagnitudePoint(hz: 1000, db: -40, phase: 0),
            MagnitudePoint(hz: 8000, db: -40, phase: 0)
        ], count: 3) + Array(repeating: narrowFrame(), count: 8)
        controller.start()
        var now = Date(timeIntervalSince1970: 0)
        for _ in 0..<3 {
            now = now.addingTimeInterval(0.2)
            controller.tick(now: now)
        }
        let faderWrites = link.log.filter { $0.0 == "write" && $0.1.hasSuffix("/fader") }
        XCTAssertEqual(faderWrites.count, 3)
        XCTAssertFalse(link.log.contains { $0.0 == "write" && $0.1.contains("/EQ/") })
        for _ in 0..<8 {
            now = now.addingTimeInterval(0.05)
            controller.tick(now: now)
        }
        let f0 = try XCTUnwrap(controller.state.firstFeedbackFader)
        XCTAssertEqual(controller.state.stopFader, .decibels(faderDbComparable(f0) + 5.0))
        XCTAssertEqual(link.values[try faderAddress(kind: .inputChannel, index: 1)], .float32(-150))
        XCTAssertTrue(link.log.contains { $0.1.contains("eq_freq_1") })
        XCTAssertEqual(controller.state.bands.count, 1)
    }

    func testPlusFiveComplete() throws {
        let (controller, smaart, link) = try makeController(startDb: 0)
        // First feedback immediately at 0 dB after start read, then clean raises with no peaks.
        smaart.frames = Array(repeating: narrowFrame(), count: 8)
            + Array(repeating: [
                MagnitudePoint(hz: 100, db: -40, phase: 0),
                MagnitudePoint(hz: 1000, db: -40, phase: 0),
                MagnitudePoint(hz: 8000, db: -40, phase: 0)
            ], count: 2000)
        controller.start()
        var now = Date(timeIntervalSince1970: 0)
        // Feed eight peak frames without raising time gaps if controller polls RTA every tick:
        for _ in 0..<8 {
            controller.tick(now: now)
            now = now.addingTimeInterval(0.01)
        }
        XCTAssertEqual(controller.state.firstFeedbackFader, .decibels(0))
        // After notch, raises from -inf toward +5
        for _ in 0..<400 {
            now = now.addingTimeInterval(0.2)
            controller.tick(now: now)
            if controller.state.phase == .done { break }
        }
        XCTAssertEqual(controller.state.phase, .done)
        XCTAssertEqual(controller.state.notice, .completePlus5)
        XCTAssertGreaterThanOrEqual(faderDbComparable(controller.state.currentFader!), 5.0 - 1e-9)
    }

    func testEightBandStop() throws {
        let (controller, smaart, _) = try makeController(startDb: -30)
        // Distinct frequencies far apart for 8 bands, each sustained once; start low so +5 not hit.
        var frames: [[MagnitudePoint]] = []
        let freqs: [Double] = [200, 400, 800, 1200, 1800, 2500, 3500, 5000, 6000]
        for hz in freqs {
            frames.append(contentsOf: Array(repeating: narrowFrame(hz: hz), count: 8))
            // quiet frames while raising again
            frames.append(contentsOf: Array(repeating: [
                MagnitudePoint(hz: 100, db: -50, phase: 0),
                MagnitudePoint(hz: 1000, db: -50, phase: 0),
                MagnitudePoint(hz: 8000, db: -50, phase: 0)
            ], count: 20))
        }
        smaart.frames = frames
        controller.start()
        var now = Date(timeIntervalSince1970: 0)
        for _ in 0..<5000 {
            controller.tick(now: now)
            now = now.addingTimeInterval(0.05)
            if controller.state.phase == .done { break }
        }
        XCTAssertEqual(controller.state.notice, .eightBands)
        XCTAssertEqual(controller.state.bands.count, 8)
        XCTAssertEqual(controller.state.currentFader, .minusInfinity)
    }

    func testStopMutesSelectedChannelAndCancelsRaises() throws {
        let (controller, smaart, link) = try makeController()
        smaart.frames = Array(repeating: [
            MagnitudePoint(hz: 100, db: -40, phase: 0),
            MagnitudePoint(hz: 1000, db: -40, phase: 0),
            MagnitudePoint(hz: 8000, db: -40, phase: 0)
        ], count: 100)
        controller.start()
        let now = Date(timeIntervalSince1970: 0)
        controller.tick(now: now.addingTimeInterval(0.2))
        let writesBefore = link.log.filter { $0.0 == "write" }.count
        controller.stop()
        XCTAssertEqual(controller.state.phase, .setup)
        XCTAssertEqual(controller.state.notice, .stopMuted)
        let muteWrites = link.log.filter { $0.1.hasSuffix("/mute") }
        XCTAssertEqual(muteWrites.count, 1)
        XCTAssertEqual(muteWrites.first?.1, try muteAddress(kind: .inputChannel, index: 1))
        XCTAssertEqual(muteWrites.first?.2, .int32(1))
        XCTAssertTrue(controller.state.channelMuted)
        let writesAfter = link.log.filter { $0.0 == "write" }.count
        controller.tick(now: now.addingTimeInterval(1.0))
        XCTAssertEqual(link.log.filter { $0.0 == "write" }.count, writesAfter)
        XCTAssertGreaterThan(writesBefore, 0)
        controller.unmute()
        XCTAssertFalse(controller.state.channelMuted)
        XCTAssertEqual(controller.state.notice, .unmuted)
        let unmuteWrites = link.log.filter { $0.1.hasSuffix("/mute") && $0.2 == .int32(0) }
        XCTAssertEqual(unmuteWrites.count, 1)
        XCTAssertEqual(unmuteWrites.first?.1, try muteAddress(kind: .inputChannel, index: 1))
    }

    func testNoRTADoesNotRaise() throws {
        let (controller, smaart, link) = try makeController()
        smaart.hasRTA = false
        controller.start()
        // start should fail or immediately notice
        if controller.state.phase == .running {
            let now = Date(timeIntervalSince1970: 0)
            controller.tick(now: now.addingTimeInterval(0.2))
            XCTAssertFalse(link.log.contains { $0.0 == "write" && $0.1.hasSuffix("/fader") && $0.2 != .float32(-150) })
        } else {
            XCTAssertEqual(controller.state.notice, .noRTA)
        }
    }
}
