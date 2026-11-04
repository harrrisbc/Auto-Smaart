import Foundation
import AutoSmaartCore
import AutoSmaartPass
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
    public static let controller: PassController = make()

    private static func make() -> PassController {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Auto-Smaart", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let session = OfficialSmaartSession(wire: URLSessionSmaartWire())
        try? session.openSession()
        let bank = CurveBank(fileURL: root.appendingPathComponent("bank.json"))
        let outputs = OutputStore(fileURL: root.appendingPathComponent("outputs.json"))
        let link = LiveConsoleLink { box.host } port: { box.port }
        let pass = PassController(reader: session, link: link, bank: bank, outputs: outputs)
        pass.endpoint = box
        pass.refreshSessionFlag()
        return pass
    }
}

final class LiveConsoleLink: OscLink {
    private let host: () -> String
    private let port: () -> String
    init(host: @escaping () -> String, port: @escaping () -> String) {
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
