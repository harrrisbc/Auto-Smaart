import XCTest
@testable import AutoSmaartRingOut
@testable import AutoSmaartCore
@testable import ConsoleOSC
@testable import SmaartAPI

final class RingOutHardwareTests: XCTestCase {
    func testOneRealRingOutPass() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["AUTO_SMAART_HARDWARE"] == "1")
        let host = try XCTUnwrap(ProcessInfo.processInfo.environment["AUTO_SMAART_CONSOLE_HOST"])
        let port = UInt16(try XCTUnwrap(ProcessInfo.processInfo.environment["AUTO_SMAART_CONSOLE_PORT"]))!
        let wire = URLSessionSmaartWire()
        let smaart = OfficialSmaartSession(wire: wire)
        try smaart.openSession()
        XCTAssertTrue(try smaart.hasActiveRTA())
        let link = try Quantum225Client(host: host, port: port)
        let controller = RingOutController(smaart: smaart, linkFactory: { _, _ in link })
        controller.updateHost(host)
        controller.updatePort(String(port))
        controller.selectFader(kind: .inputChannel, index: 1)
        controller.selectEQ(kind: .matrixBus, index: 1)
        controller.start()
        let deadline = Date().addingTimeInterval(120)
        while Date() < deadline && controller.state.phase != .done && controller.state.phase != .setup {
            controller.tick(now: Date())
            Thread.sleep(forTimeInterval: 0.05)
        }
        controller.stop()
        XCTAssertTrue(
            controller.state.notice == .stopMuted
                || controller.state.notice == .stopMuteIncomplete
                || controller.state.phase == .done
                || controller.state.phase == .setup
        )
    }
}
