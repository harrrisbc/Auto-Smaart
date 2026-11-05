import Foundation
import AutoSmaartCore
import ConsoleOSC
import SmaartAPI
@testable import AutoSmaartPass

final class ScriptedReader: SmaartReader {
    var isSessionOpen: Bool
    var preferredMeasurementName = ""
    var traces: [SmaartCapture]
    var target: [MagnitudePoint]?
    private(set) var traceReads = 0
    private(set) var generatorActiveLog: [Bool] = []

    init(traces: [SmaartCapture], target: [MagnitudePoint]? = nil, open: Bool = true) {
        self.traces = traces
        self.target = target
        self.isSessionOpen = open
    }

    func openSession() throws { isSessionOpen = true }
    func closeSession() { isSessionOpen = false }

    func setSignalGeneratorActive(_ active: Bool) throws {
        guard isSessionOpen else { throw SmaartReaderError.sessionClosed }
        generatorActiveLog.append(active)
    }

    func readTrace() throws -> SmaartCapture {
        traceReads += 1
        guard !traces.isEmpty else { throw SmaartReaderError.noTrace }
        return traces.removeFirst()
    }

    func readTargetCurve() throws -> [MagnitudePoint] {
        guard let target, !target.isEmpty else { throw SmaartReaderError.noTarget }
        return target
    }
}

final class RecordingLink: OscLink {
    var values: [String: OscValue]
    private(set) var log: [(op: String, address: String, value: OscValue?)] = []
    var failAddresses: Set<String> = []

    init(values: [String: OscValue] = [:]) { self.values = values }

    func read(address: String) throws -> OscValue {
        log.append(("read", address, nil))
        if failAddresses.contains(address) { throw OscTransportError.notAccepted }
        return values[address] ?? .float32(0)
    }

    func write(address: String, value: OscValue) throws {
        log.append(("write", address, value))
        if failAddresses.contains(address) { throw OscTransportError.notAccepted }
        values[address] = value
    }
}

@MainActor
func makePass(
    traces: [SmaartCapture],
    target: [MagnitudePoint]? = nil,
    link: RecordingLink = RecordingLink()
) -> (PassController, ScriptedReader, RecordingLink, URL) {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let reader = ScriptedReader(traces: traces, target: target)
    let bank = CurveBank(fileURL: directory.appendingPathComponent("bank.json"))
    let outputs = OutputStore(fileURL: directory.appendingPathComponent("outputs.json"))
    let pass = PassController(reader: reader, link: link, bank: bank, outputs: outputs)
    return (pass, reader, link, directory)
}

@MainActor
func prepare(_ pass: PassController, points: [MagnitudePoint]) throws {
    try pass.storePreparedPreset(name: "Main", kind: .reference, points: points)
    try pass.storePreparedPreset(name: "Other", kind: .target, points: points)
    pass.setHost("10.0.0.8")
    pass.setPort("8000")
    pass.selectOutput(1)
    pass.recall(name: "Main")
}

func capture(magnitude: [MagnitudePoint], finder: Double?, impulse: Impulse? = nil) -> SmaartCapture {
    SmaartCapture(magnitude: magnitude, delayFinderMs: finder, impulse: impulse)
}
