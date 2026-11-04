import Foundation
import AutoSmaartCore

let smaartAPIURL = URL(string: "ws://127.0.0.1:26000/api/v4/")!

public enum SmaartReaderError: Error, Equatable {
    case noTrace
    case noTarget
    case sessionClosed
}

public protocol SmaartReader: AnyObject {
    func openSession() throws
    func closeSession()
    var isSessionOpen: Bool { get }
    func readTrace() throws -> SmaartCapture
    func readTargetCurve() throws -> [MagnitudePoint]
}

protocol SmaartWire: AnyObject {
    func connect() throws
    func close()
    var isOpen: Bool { get }
    func send(_ text: String) throws
    func receive() throws -> String
}

final class URLSessionSmaartWire: SmaartWire {
    private let task: URLSessionWebSocketTask
    private let session: URLSession
    private(set) var isOpen = false

    init(url: URL = smaartAPIURL) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        session = URLSession(configuration: configuration)
        task = session.webSocketTask(with: url)
    }

    func connect() throws {
        task.resume()
        isOpen = true
    }

    func close() {
        task.cancel(with: .normalClosure, reason: nil)
        isOpen = false
    }

    func send(_ text: String) throws {
        let semaphore = DispatchSemaphore(value: 0)
        var sendError: Error?
        task.send(.string(text)) { error in
            sendError = error
            semaphore.signal()
        }
        semaphore.wait()
        if let sendError { throw sendError }
    }

    func receive() throws -> String {
        let semaphore = DispatchSemaphore(value: 0)
        var received: Result<String, Error>?
        task.receive { result in
            switch result {
            case .success(let message):
                if case .string(let text) = message { received = .success(text) }
                else { received = .failure(SmaartReaderError.noTrace) }
            case .failure(let error):
                received = .failure(error)
            }
            semaphore.signal()
        }
        semaphore.wait()
        switch received {
        case .success(let text): return text
        case .failure(let error): throw error
        case .none: throw SmaartReaderError.noTrace
        }
    }
}

final class OfficialSmaartSession: SmaartReader {
    private let wire: SmaartWire
    private(set) var isSessionOpen = false

    init(wire: SmaartWire) { self.wire = wire }

    func openSession() throws {
        try wire.connect()
        let reply: [String: Any]
        do {
            reply = try request(["action": "get", "target": "measurements"])
        } catch {
            wire.close()
            isSessionOpen = false
            throw error
        }
        if reply["error"] as? String == "authentication required"
            || reply["error"] as? String == "incorrect password" {
            wire.close()
            isSessionOpen = false
            throw SmaartReaderError.sessionClosed
        }
        isSessionOpen = true
    }

    func closeSession() {
        wire.close()
        isSessionOpen = false
    }

    func readTrace() throws -> SmaartCapture {
        guard isSessionOpen else { throw SmaartReaderError.sessionClosed }
        let measurements = try request(["action": "get", "target": "measurements"])
        let rows = measurements["transferFunctionMeasurements"] as? [[String: Any]] ?? []
        guard let name = rows.first(where: { $0["active"] as? Bool == true })?["measurementName"] as? String else {
            throw SmaartReaderError.noTrace
        }
        let finderReply = try request([
            "action": "findDelay",
            "target": ["measurementName": name],
            "properties": [
                ["automaticallyStart": true],
                ["automaticallyInsert": false],
                ["automaticallyStop": true]
            ]
        ])
        let body = try request(["action": "get", "target": ["measurementName": name]])
        let magnitude = magnitudePoints(body["magnitude"] as? [[String: Any]] ?? [])
        if magnitude.isEmpty { throw SmaartReaderError.noTrace }
        return SmaartCapture(
            magnitude: magnitude,
            delayFinderMs: number(finderReply["delayFinderMs"]),
            impulse: impulse(body["impulse"] as? [String: Any])
        )
    }

    func readTargetCurve() throws -> [MagnitudePoint] {
        guard isSessionOpen else { throw SmaartReaderError.sessionClosed }
        let reply = try request(["action": "get", "target": "targetCurve"])
        if reply["error"] != nil { throw SmaartReaderError.noTarget }
        guard let rows = reply["points"] as? [[String: Any]] else { throw SmaartReaderError.noTarget }
        let points = rows.compactMap { row -> MagnitudePoint? in
            guard let hz = number(row["hz"]), let db = number(row["db"]) else { return nil }
            return MagnitudePoint(hz: hz, db: db, phase: 0)
        }
        if points.isEmpty { throw SmaartReaderError.noTarget }
        return points
    }

    private func request(_ payload: [String: Any]) throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        try wire.send(String(data: data, encoding: .utf8)!)
        let text = try wire.receive()
        return try decodeObject(text)
    }

    private func decodeObject(_ text: String) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: Data(text.utf8))
        return object as? [String: Any] ?? [:]
    }

    private func magnitudePoints(_ rows: [[String: Any]]) -> [MagnitudePoint] {
        rows.compactMap { row in
            guard let hz = number(row["hz"]), let db = number(row["db"]) else { return nil }
            return MagnitudePoint(hz: hz, db: db, phase: number(row["phase"]) ?? 0)
        }
    }

    private func impulse(_ object: [String: Any]?) -> Impulse? {
        guard let object, let sampleRate = number(object["sampleRate"]), let samples = numbers(object["samples"]) else {
            return nil
        }
        return Impulse(sampleRate: sampleRate, samples: samples)
    }

    private func number(_ value: Any?) -> Double? {
        if value is NSNull || value == nil { return nil }
        if let value = value as? NSNumber, CFGetTypeID(value) == CFBooleanGetTypeID() { return nil }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }

    private func numbers(_ value: Any?) -> [Double]? {
        guard let rows = value as? [Any] else { return nil }
        return rows.compactMap { number($0) }
    }
}
