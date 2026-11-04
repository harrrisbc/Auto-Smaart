import Foundation

public struct MagnitudePoint: Equatable, Codable {
    public var hz: Double
    public var db: Double
    public var phase: Double
    public init(hz: Double, db: Double, phase: Double) {
        self.hz = hz
        self.db = db
        self.phase = phase
    }
}

struct Impulse: Equatable, Codable {
    var sampleRate: Double
    var samples: [Double]
}

struct SmaartCapture: Equatable, Codable {
    var magnitude: [MagnitudePoint]
    var delayFinderMs: Double?
    var impulse: Impulse?
}

public enum CurveKind: String, Equatable, Codable {
    case target
    case reference
}

public struct CurvePreset: Equatable, Codable {
    public var name: String
    public var kind: CurveKind
    public var points: [MagnitudePoint]
    public init(name: String, kind: CurveKind, points: [MagnitudePoint]) {
        self.name = name
        self.kind = kind
        self.points = points
    }
}

public struct EqBand: Equatable, Codable {
    public var index: Int
    public var hz: Double
    public var gainDb: Double
    public var q: Double
    public init(index: Int, hz: Double, gainDb: Double, q: Double) {
        self.index = index
        self.hz = hz
        self.gainDb = gainDb
        self.q = q
    }
}

public enum OscValue: Equatable, Codable {
    case float32(Float)
    case int32(Int32)

    private enum Key: String, CodingKey { case kind, value }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case .float32(let value):
            try container.encode("float32", forKey: .kind)
            try container.encode(value, forKey: .value)
        case .int32(let value):
            try container.encode("int32", forKey: .kind)
            try container.encode(value, forKey: .value)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let kind = try container.decode(String.self, forKey: .kind)
        if kind == "float32" {
            self = .float32(try container.decode(Float.self, forKey: .value))
        } else if kind == "int32" {
            self = .int32(try container.decode(Int32.self, forKey: .value))
        } else {
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "unknown OSC kind")
        }
    }
}
