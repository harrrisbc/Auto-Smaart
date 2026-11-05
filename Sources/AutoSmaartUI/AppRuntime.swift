import Foundation
import AutoSmaartCore
import AutoSmaartPass
import AutoSmaartRingOut
import SmaartAPI
import ConsoleOSC

public final class HostPortBox: ConsoleEndpoint {
    public var host = ""
    public var port = ""
    public init() {}
    public func update(host: String, port: String) {
        self.host = host
        self.port = port
    }
}

public enum AppRuntime {
    public static let box = HostPortBox()
    public static let session = OfficialSmaartSession(wire: URLSessionSmaartWire())
    public static let controller: PassController = makePass()
    public static let ringOut: RingOutController = makeRingOut()
    public static let liveLink = LiveConsoleLink(host: { box.host }, port: { box.port })

    private static func makePass() -> PassController {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Auto-Smaart", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let bank = CurveBank(fileURL: root.appendingPathComponent("bank.json"))
        let outputs = OutputStore(fileURL: root.appendingPathComponent("outputs.json"))
        let pass = PassController(reader: session, link: liveLink, bank: bank, outputs: outputs)
        pass.endpoint = box
        // openSession blocks on URLSession WebSocket semaphores. Doing that on the main
        // thread during SwiftUI startup freezes/kills the window once Smaart is live.
        DispatchQueue.global(qos: .userInitiated).async {
            try? session.openSession()
            DispatchQueue.main.async {
                pass.refreshSessionFlag()
            }
        }
        return pass
    }

    private static func makeRingOut() -> RingOutController {
        let ring = RingOutController(smaart: session, linkFactory: { host, port in
            box.host = host
            box.port = String(port)
            return liveLink
        })
        return ring
    }
}

public final class LiveConsoleLink: OscLink {
    private let host: () -> String
    private let port: () -> String
    public init(host: @escaping () -> String, port: @escaping () -> String) {
        self.host = host
        self.port = port
    }
    public func read(address: String) throws -> OscValue {
        let client = try open()
        defer { client.close() }
        return try client.read(address: address)
    }
    public func write(address: String, value: OscValue) throws {
        let client = try open()
        defer { client.close() }
        try client.write(address: address, value: value)
    }
    private func open() throws -> Quantum225Client {
        guard let port = UInt16(port()), !host().isEmpty else { throw OscTransportError.badHost }
        return try Quantum225Client(host: host(), port: port)
    }
}
