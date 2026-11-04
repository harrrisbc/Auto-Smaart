import Foundation
import AutoSmaartCore

public struct DelaySnapshot: Equatable, Codable {
    public var delay: OscValue
    public var fineDelay: OscValue
    public init(delay: OscValue, fineDelay: OscValue) {
        self.delay = delay
        self.fineDelay = fineDelay
    }
}

public struct EqBandSnapshot: Equatable, Codable {
    public var index: Int
    public var freq: OscValue
    public var gain: OscValue
    public var q: OscValue
    public var on: OscValue
    public init(index: Int, freq: OscValue, gain: OscValue, q: OscValue, on: OscValue) {
        self.index = index
        self.freq = freq
        self.gain = gain
        self.q = q
        self.on = on
    }
}

public struct MatrixOutputRecord: Equatable, Codable {
    public var index: Int
    public var displayName: String
    public var lastWrite: String?
    public var delaySnapshot: DelaySnapshot?
    public var eqSnapshot: [EqBandSnapshot]?
    public init(index: Int, displayName: String, lastWrite: String?, delaySnapshot: DelaySnapshot?, eqSnapshot: [EqBandSnapshot]?) {
        self.index = index
        self.displayName = displayName
        self.lastWrite = lastWrite
        self.delaySnapshot = delaySnapshot
        self.eqSnapshot = eqSnapshot
    }
}

public final class OutputStore {
    private let fileURL: URL
    public private(set) var outputs: [MatrixOutputRecord]

    public init(fileURL: URL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([MatrixOutputRecord].self, from: data),
           decoded.count == 12 {
            outputs = decoded
        } else {
            outputs = (1...12).map {
                MatrixOutputRecord(index: $0, displayName: "", lastWrite: nil, delaySnapshot: nil, eqSnapshot: nil)
            }
        }
    }

    public func save(_ outputs: [MatrixOutputRecord]) throws {
        self.outputs = outputs
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(outputs).write(to: fileURL, options: .atomic)
    }
}
