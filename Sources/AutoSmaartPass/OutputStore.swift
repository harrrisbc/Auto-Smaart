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

private struct StoredBusOutputs: Codable {
    var matrix: [MatrixOutputRecord]
    var mix: [MatrixOutputRecord]
}

public final class OutputStore {
    private let fileURL: URL
    public private(set) var outputs: [MatrixOutputRecord]
    public private(set) var mixOutputs: [MatrixOutputRecord]

    public init(fileURL: URL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let bundled = try? JSONDecoder().decode(StoredBusOutputs.self, from: data),
           bundled.matrix.count == 12, bundled.mix.count == 24 {
            outputs = bundled.matrix
            mixOutputs = bundled.mix
        } else if let data = try? Data(contentsOf: fileURL),
                  let decoded = try? JSONDecoder().decode([MatrixOutputRecord].self, from: data),
                  decoded.count == 12 {
            outputs = decoded
            mixOutputs = Self.blankMix()
        } else {
            outputs = Self.blankMatrix()
            mixOutputs = Self.blankMix()
        }
    }

    public func save(matrix: [MatrixOutputRecord], mix: [MatrixOutputRecord]) throws {
        outputs = matrix
        mixOutputs = mix
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let payload = StoredBusOutputs(matrix: matrix, mix: mix)
        try JSONEncoder().encode(payload).write(to: fileURL, options: .atomic)
    }

    /// Compatibility for matrix-only callers.
    public func save(_ outputs: [MatrixOutputRecord]) throws {
        try save(matrix: outputs, mix: mixOutputs)
    }

    private static func blankMatrix() -> [MatrixOutputRecord] {
        (1...12).map {
            MatrixOutputRecord(index: $0, displayName: "", lastWrite: nil, delaySnapshot: nil, eqSnapshot: nil)
        }
    }

    private static func blankMix() -> [MatrixOutputRecord] {
        (1...24).map {
            MatrixOutputRecord(index: $0, displayName: "", lastWrite: nil, delaySnapshot: nil, eqSnapshot: nil)
        }
    }
}
