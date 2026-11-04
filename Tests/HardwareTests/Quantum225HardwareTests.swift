import XCTest
import AutoSmaartCore
import SmaartAPI
import ConsoleOSC
@testable import AutoSmaartPass

@MainActor
final class Quantum225HardwareTests: XCTestCase {
    func testOneMatrixDelayThenEqThenRemeasure() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["AUTO_SMAART_HARDWARE"] == "1" else {
            throw XCTSkip("Set AUTO_SMAART_HARDWARE=1, AUTO_SMAART_CONSOLE_HOST, AUTO_SMAART_CONSOLE_PORT, and AUTO_SMAART_MATRIX to run one Quantum 225 pass.")
        }
        let host = try XCTUnwrap(env["AUTO_SMAART_CONSOLE_HOST"])
        let portText = try XCTUnwrap(env["AUTO_SMAART_CONSOLE_PORT"])
        let port = try XCTUnwrap(UInt16(portText))
        let matrix = try XCTUnwrap(Int(env["AUTO_SMAART_MATRIX"] ?? ""))
        XCTAssertTrue((1...12).contains(matrix))
        let session = OfficialSmaartSession(wire: URLSessionSmaartWire())
        try session.openSession()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let bank = CurveBank(fileURL: directory.appendingPathComponent("bank.json"))
        let outputs = OutputStore(fileURL: directory.appendingPathComponent("outputs.json"))
        let link = try Quantum225Client(host: host, port: port)
        defer { link.close() }
        let pass = PassController(reader: session, link: link, bank: bank, outputs: outputs)
        pass.setHost(host)
        pass.setPort(portText)
        pass.selectOutput(matrix)
        try pass.storePreparedPreset(name: "Hardware target", kind: .target, points: [
            MagnitudePoint(hz: 20, db: 40, phase: 0),
            MagnitudePoint(hz: 20000, db: 40, phase: 0)
        ])
        pass.recall(name: "Hardware target")
        pass.readTrace()
        XCTAssertEqual(pass.state.step, .delay, PassPresenter.noticeText(pass.state.notice) ?? "")
        pass.confirmDelay()
        if pass.state.notice == .couldNotRemeasure { pass.retryRemeasure() }
        XCTAssertEqual(pass.state.step, .eq, PassPresenter.noticeText(pass.state.notice) ?? "")
        XCTAssertFalse(pass.state.bands?.isEmpty ?? true)
        pass.confirmEq()
        XCTAssertEqual(pass.state.step, .compare)
        XCTAssertNotNil(pass.state.afterCurve)
        let snapshot = try XCTUnwrap(pass.state.outputs[matrix - 1].delaySnapshot)
        pass.undoLastWrite()
        let addresses = try delayAddresses(output: matrix)
        XCTAssertEqual(try link.read(address: addresses.delay), snapshot.delay)
        XCTAssertEqual(try link.read(address: addresses.fineDelay), snapshot.fineDelay)
    }
}
