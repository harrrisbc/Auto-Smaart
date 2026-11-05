import Foundation
import AutoSmaartCore

public let smaartAPIURL = URL(string: "ws://127.0.0.1:26000/api/v4/")!

public enum SmaartReaderError: Error, Equatable {
    case noTrace
    case noTarget
    case sessionClosed
    case noRTA
}

public protocol SmaartReader: AnyObject {
    func openSession() throws
    func closeSession()
    var isSessionOpen: Bool { get }
    /// When non-empty after trim, read this TF name; when blank, use the first active TF.
    var preferredMeasurementName: String { get set }
    func readTrace() throws -> SmaartCapture
    func readTargetCurve() throws -> [MagnitudePoint]
    func hasActiveRTA() throws -> Bool
    func readRTA() throws -> [MagnitudePoint]
    /// Turns the Smaart signal generator output on or off. Does not stop TF/RTA engines.
    func setSignalGeneratorActive(_ active: Bool) throws
}

public protocol SmaartWire: AnyObject {
    func connect() throws
    func close()
    var isOpen: Bool { get }
    func send(_ text: String) throws
    func receive() throws -> String
}

public final class URLSessionSmaartWire: SmaartWire {
    private let task: URLSessionWebSocketTask
    private let session: URLSession
    public private(set) var isOpen = false

    public init(url: URL = smaartAPIURL) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        session = URLSession(configuration: configuration)
        task = session.webSocketTask(with: url)
    }

    public func connect() throws {
        task.resume()
        isOpen = true
    }

    public func close() {
        task.cancel(with: .normalClosure, reason: nil)
        isOpen = false
    }

    public func send(_ text: String) throws {
        let semaphore = DispatchSemaphore(value: 0)
        var sendError: Error?
        task.send(.string(text)) { error in
            sendError = error
            semaphore.signal()
        }
        semaphore.wait()
        if let sendError { throw sendError }
    }

    public func receive() throws -> String {
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

public final class OfficialSmaartSession: SmaartReader {
    private enum SpectrumCache {
        case unknown
        case none
        case name(String)
    }

    private let wire: SmaartWire
    public private(set) var isSessionOpen = false
    public var preferredMeasurementName = ""
    private var spectrumCache: SpectrumCache = .unknown

    public init(wire: SmaartWire) { self.wire = wire }

    public func openSession() throws {
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
        spectrumCache = .unknown
    }

    public func closeSession() {
        wire.close()
        isSessionOpen = false
        spectrumCache = .unknown
    }

    public func readTrace() throws -> SmaartCapture {
        guard isSessionOpen else { throw SmaartReaderError.sessionClosed }
        let measurements = try request(["action": "get", "target": "measurements"])
        let rows = measurements["transferFunctionMeasurements"] as? [[String: Any]] ?? []
        let preferred = preferredMeasurementName.trimmingCharacters(in: .whitespacesAndNewlines)
        let row: [String: Any]
        let name: String
        if !preferred.isEmpty {
            guard let match = rows.first(where: { ($0["measurementName"] as? String) == preferred }),
                  let matchedName = match["measurementName"] as? String else {
                throw SmaartReaderError.noTrace
            }
            row = match
            name = matchedName
        } else {
            // Prefer the active TF; fall back to the first named TF when paused.
            guard let match = rows.first(where: { isActiveFlag($0["active"]) })
                    ?? rows.first(where: { ($0["measurementName"] as? String)?.isEmpty == false }),
                  let matchedName = match["measurementName"] as? String else {
                throw SmaartReaderError.noTrace
            }
            row = match
            name = matchedName
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
        // Live v9 returns "delay"; fixtures and older docs use "delayFinderMs".
        let delayMs = number(finderReply["delayFinderMs"]) ?? number(finderReply["delay"])

        let body = try request(["action": "get", "target": ["measurementName": name]])
        var magnitude = magnitudePoints(body["magnitude"] as? [[String: Any]] ?? [])
        if magnitude.isEmpty {
            magnitude = magnitudeFromPairData(body["data"])
        }
        if magnitude.isEmpty {
            // Active rows include streamEndpoint; inactive rows omit it — build the known path.
            let endpoint = (row["streamEndpoint"] as? String)
                ?? "/api/v4/measurements/\(name)"
            let frame = try receiveStreamFrame(path: endpoint)
            magnitude = magnitudeFromPairData(frame["data"])
        }
        if magnitude.isEmpty { throw SmaartReaderError.noTrace }
        return SmaartCapture(
            magnitude: magnitude,
            delayFinderMs: delayMs,
            impulse: impulse(body["impulse"] as? [String: Any])
        )
    }

    public func readTargetCurve() throws -> [MagnitudePoint] {
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

    public func hasActiveRTA() throws -> Bool {
        guard isSessionOpen else { throw SmaartReaderError.sessionClosed }
        if let name = try fetchActiveSpectrumName() {
            spectrumCache = .name(name)
            return true
        }
        spectrumCache = .none
        return false
    }

    public func readRTA() throws -> [MagnitudePoint] {
        guard isSessionOpen else { throw SmaartReaderError.sessionClosed }
        let name: String
        switch spectrumCache {
        case .name(let cached):
            name = cached
        case .none:
            throw SmaartReaderError.noRTA
        case .unknown:
            guard let fetched = try fetchActiveSpectrumName() else { throw SmaartReaderError.noRTA }
            spectrumCache = .name(fetched)
            name = fetched
        }
        let body = try request(["action": "get", "target": ["measurementName": name]])
        let magnitude = magnitudePoints(body["magnitude"] as? [[String: Any]] ?? [])
        if magnitude.isEmpty { throw SmaartReaderError.noRTA }
        return magnitude
    }

    public func setSignalGeneratorActive(_ active: Bool) throws {
        guard isSessionOpen else { throw SmaartReaderError.sessionClosed }
        let reply = try request([
            "action": "set",
            "target": "signalGenerator",
            "properties": [["active": active]]
        ])
        if reply["error"] != nil { throw SmaartReaderError.sessionClosed }
    }

    private func fetchActiveSpectrumName() throws -> String? {
        let measurements = try request(["action": "get", "target": "measurements"])
        let rows = measurements["spectrumMeasurements"] as? [[String: Any]] ?? []
        return rows.first(where: { isActiveFlag($0["active"]) })?["measurementName"] as? String
    }

    private func request(_ payload: [String: Any]) throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        try wire.send(String(data: data, encoding: .utf8)!)
        let text = try wire.receive()
        return try decodeObject(text)
    }

    private func decodeObject(_ text: String) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: Data(text.utf8))
        guard let dict = object as? [String: Any] else { return [:] }
        // Live Smaart v4 wraps payloads as {"response":{...}}; keep top-level errors as-is.
        if dict["error"] != nil { return dict }
        if let response = dict["response"] as? [String: Any] { return response }
        return dict
    }

    private func receiveStreamFrame(path: String) throws -> [String: Any] {
        var components = URLComponents(url: smaartAPIURL, resolvingAgainstBaseURL: false)!
        components.path = path
        components.query = nil
        guard let url = components.url else { throw SmaartReaderError.noTrace }
        let stream = URLSessionSmaartWire(url: url)
        try stream.connect()
        defer { stream.close() }
        let text = try stream.receive()
        let object = try JSONSerialization.jsonObject(with: Data(text.utf8))
        // Stream frames are bare objects (no response envelope).
        return object as? [String: Any] ?? [:]
    }

    private func magnitudePoints(_ rows: [[String: Any]]) -> [MagnitudePoint] {
        rows.compactMap { row in
            guard let hz = number(row["hz"]), let db = number(row["db"]) else { return nil }
            return MagnitudePoint(hz: hz, db: db, phase: number(row["phase"]) ?? 0)
        }
    }

    /// Live TF stream uses `data: [[hz, db], ...]`.
    private func magnitudeFromPairData(_ value: Any?) -> [MagnitudePoint] {
        guard let rows = value as? [[Any]] else { return [] }
        return rows.compactMap { row in
            guard row.count >= 2, let hz = number(row[0]), let db = number(row[1]) else { return nil }
            let phase = row.count >= 3 ? (number(row[2]) ?? 0) : 0
            return MagnitudePoint(hz: hz, db: db, phase: phase)
        }
    }

    private func impulse(_ object: [String: Any]?) -> Impulse? {
        guard let object, let sampleRate = number(object["sampleRate"]), let samples = numbers(object["samples"]) else {
            return nil
        }
        return Impulse(sampleRate: sampleRate, samples: samples)
    }

    private func isActiveFlag(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        return false
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
