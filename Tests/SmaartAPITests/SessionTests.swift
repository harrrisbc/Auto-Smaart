import XCTest
@testable import SmaartAPI
@testable import AutoSmaartCore

final class ScriptedWire: SmaartWire {
    var sent: [String] = []
    var replies: [String]
    var isOpen = false
    init(replies: [String]) { self.replies = replies }
    func connect() throws { isOpen = true }
    func close() { isOpen = false }
    func send(_ text: String) throws { sent.append(text) }
    func receive() throws -> String {
        guard !replies.isEmpty else { throw SmaartReaderError.noTrace }
        return replies.removeFirst()
    }
}

final class SessionTests: XCTestCase {
    func testURLIsLocalAPIVersion4() {
        XCTAssertEqual(smaartAPIURL.absoluteString, "ws://127.0.0.1:26000/api/v4/")
    }

    func testFinderIsKeptWhenImpulseIsAlsoInThePayload() throws {
        let measurements = #"{"transferFunctionMeasurements":[{"measurementName":"Later","active":false},{"measurementName":"TF","active":true}]}"#
        let wire = ScriptedWire(replies: [
            measurements,
            measurements,
            #"{"delayFinderMs":12.35}"#,
            #"{"magnitude":[{"hz":1000,"db":-3,"phase":15}],"impulse":{"sampleRate":48000,"samples":[0,0,1]},"coherence":0.9}"#
        ])
        let session = OfficialSmaartSession(wire: wire)
        try session.openSession()
        XCTAssertTrue(session.isSessionOpen)
        let capture = try session.readTrace()
        XCTAssertEqual(capture.delayFinderMs, 12.35)
        XCTAssertEqual(capture.magnitude, [MagnitudePoint(hz: 1000, db: -3, phase: 15)])
        XCTAssertEqual(capture.impulse?.samples, [0, 0, 1])
        XCTAssertEqual(delaySuggestion(of: capture), .milliseconds(12.35))
        let sent = try wire.sent.map { try JSONDecoder().decode(JSONValue.self, from: Data($0.utf8)) }
        let getMeasurements = JSONValue.object(["action": .string("get"), "target": .string("measurements")])
        XCTAssertEqual(sent[0], getMeasurements)
        XCTAssertEqual(sent[1], getMeasurements)
        XCTAssertEqual(sent[2], JSONValue.object([
            "action": .string("findDelay"),
            "target": .object(["measurementName": .string("TF")]),
            "properties": .array([
                .object(["automaticallyStart": .bool(true)]),
                .object(["automaticallyInsert": .bool(false)]),
                .object(["automaticallyStop": .bool(true)])
            ])
        ]))
    }

    func testMissingFinderLeavesImpulseForTheDelayRule() throws {
        let measurements = #"{"transferFunctionMeasurements":[{"measurementName":"TF","active":true}]}"#
        let wire = ScriptedWire(replies: [
            measurements,
            measurements,
            #"{"error":"not implemented"}"#,
            #"{"magnitude":[{"hz":1000,"db":0}],"impulse":{"sampleRate":48000,"samples":[0,0.1,-0.4,0.9,0.9]}}"#
        ])
        let session = OfficialSmaartSession(wire: wire)
        try session.openSession()
        let capture = try session.readTrace()
        XCTAssertNil(capture.delayFinderMs)
        XCTAssertEqual(capture.magnitude.first?.phase, 0)
        XCTAssertEqual(delaySuggestion(of: capture), .milliseconds(0.0625))
    }

    func testNoActiveTransferFunctionIsNoTrace() throws {
        let empty = #"{"spectrumMeasurements":[{"measurementName":"RTA","active":true}],"transferFunctionMeasurements":[]}"#
        let wire = ScriptedWire(replies: [empty, empty])
        let session = OfficialSmaartSession(wire: wire)
        try session.openSession()
        XCTAssertThrowsError(try session.readTrace()) { error in
            XCTAssertEqual(error as? SmaartReaderError, .noTrace)
        }
    }

    func testTargetCurveAndMissingTarget() throws {
        let wire = ScriptedWire(replies: [
            #"{"transferFunctionMeasurements":[]}"#,
            #"{"points":[{"hz":100,"db":0},{"hz":1000,"db":-6}]}"#,
            #"{"error":"unknown target"}"#
        ])
        let session = OfficialSmaartSession(wire: wire)
        try session.openSession()
        let points = try session.readTargetCurve()
        XCTAssertEqual(points, [
            MagnitudePoint(hz: 100, db: 0, phase: 0),
            MagnitudePoint(hz: 1000, db: -6, phase: 0)
        ])
        XCTAssertThrowsError(try session.readTargetCurve()) { error in
            XCTAssertEqual(error as? SmaartReaderError, .noTarget)
        }
    }

    func testAuthenticationRequiredDoesNotOpen() {
        let wire = ScriptedWire(replies: [#"{"error":"authentication required"}"#])
        let session = OfficialSmaartSession(wire: wire)
        XCTAssertThrowsError(try session.openSession())
        XCTAssertFalse(session.isSessionOpen)
        XCTAssertFalse(wire.isOpen)
    }

    func testReadBeforeOpenThrowsSessionClosed() {
        let session = OfficialSmaartSession(wire: ScriptedWire(replies: []))
        XCTAssertThrowsError(try session.readTrace()) { error in
            XCTAssertEqual(error as? SmaartReaderError, .sessionClosed)
        }
    }
}

enum JSONValue: Equatable {
    case string(String)
    case bool(Bool)
    case number(Double)
    case object([String: JSONValue])
    case array([JSONValue])
    case null
}

extension JSONValue: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(Double.self) { self = .number(value); return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        if let value = try? container.decode([String: JSONValue].self) { self = .object(value); return }
        if let value = try? container.decode([JSONValue].self) { self = .array(value); return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "unknown JSON")
    }
}
