import XCTest
import SwiftUI
@testable import AutoSmaartUI
@testable import AutoSmaartRingOut
@testable import AutoSmaartCore
@testable import ConsoleOSC
@testable import SmaartAPI

final class RingOutUIMemoryLink: OscLink {
    var values: [String: OscValue]
    var log: [(String, String, OscValue?)] = []
    init(values: [String: OscValue]) { self.values = values }
    func read(address: String) throws -> OscValue {
        log.append(("read", address, nil))
        guard let value = values[address] else { throw ConfirmError.kept }
        return value
    }
    func write(address: String, value: OscValue) throws {
        log.append(("write", address, value))
        values[address] = value
    }
}

final class RingOutUIFakeRTA: SmaartReader {
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

@MainActor
final class RingOutShellTests: XCTestCase {
    func testOnePageSourcesDoNotUseStepScreens() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent("Sources/AutoSmaartUI")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let source = try files.filter { $0.pathExtension == "swift" }.map { try String(contentsOf: $0) }.joined(separator: "\n")
        XCTAssertTrue(source.contains("RingOutPage"))
        XCTAssertTrue(source.contains("RingOutPresenter"))
        XCTAssertTrue(source.contains("stopAction"))
        XCTAssertTrue(source.contains("smaartLive") || source.contains("Smaart live"))
        XCTAssertTrue(source.contains("100") && source.contains("8000"))
        XCTAssertTrue(source.contains("leaveAction"))
        XCTAssertTrue(source.contains("PassPresenter.settings") || source.contains("Settings"))
        XCTAssertTrue(source.contains("SettingsView"))
        XCTAssertTrue(source.contains("Ring Out"))
        for forbidden in ["RingOutSetupView", "RingOutRunningView", "RingOutNotchView", "RingOutDoneView", "/sd/Input_Channels", "decideNotch", "CGWindowListCreateImage"] {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
    }

    func testRingOutPageEvaluates() throws {
        let fader = try faderAddress(kind: .inputChannel, index: 1)
        let link = RingOutUIMemoryLink(values: [fader: .float32(-20)])
        let smaart = RingOutUIFakeRTA()
        try smaart.openSession()
        smaart.hasRTA = true
        let controller = RingOutController(smaart: smaart, linkFactory: { _, _ in link })
        controller.updateHost("127.0.0.1")
        controller.updatePort("9000")
        _ = RingOutPage(controller: controller, calibration: nil, onLeave: {}).body
        _ = ShellView(mode: .constant(.ringOut), calibration: nil, ringOut: controller).body
    }
}
