import Foundation
import AutoSmaartCore
import AutoSmaartPass
import ConsoleOSC
import SmaartAPI

/// Task 13 compile stub so the Mac window builds. Task 14 replaces this with the live Smaart/OSC wiring.
enum AppRuntime {
    static let controller: PassController = make()

    private static func make() -> PassController {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Auto-Smaart", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let bank = CurveBank(fileURL: root.appendingPathComponent("bank.json"))
        let outputs = OutputStore(fileURL: root.appendingPathComponent("outputs.json"))
        return PassController(reader: IdleSmaartReader(), link: IdleOscLink(), bank: bank, outputs: outputs)
    }
}

final class IdleSmaartReader: SmaartReader {
    private(set) var isSessionOpen = false
    func openSession() throws { isSessionOpen = true }
    func closeSession() { isSessionOpen = false }
    func readTrace() throws -> SmaartCapture { throw SmaartReaderError.noTrace }
    func readTargetCurve() throws -> [MagnitudePoint] { throw SmaartReaderError.noTarget }
}

final class IdleOscLink: OscLink {
    func read(address: String) throws -> OscValue { throw OscTransportError.badHost }
    func write(address: String, value: OscValue) throws { throw OscTransportError.badHost }
}
