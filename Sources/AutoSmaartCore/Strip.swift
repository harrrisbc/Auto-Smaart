import Foundation

public enum StripKind: String, Equatable, Codable, CaseIterable {
    case inputChannel
    case groupBus
    case auxBus
    case matrixBus
}

public func stripIndexRange(_ kind: StripKind) -> ClosedRange<Int> {
    switch kind {
    case .inputChannel: return 1...72
    case .groupBus, .auxBus: return 1...24
    case .matrixBus: return 1...12
    }
}

public enum FaderLevel: Equatable {
    case minusInfinity
    case decibels(Double)
}

public let digicoFaderMinusInfinityWire: Float = -150.0

public func faderLevel(fromWire value: Float) -> FaderLevel {
    if value <= digicoFaderMinusInfinityWire { return .minusInfinity }
    return .decibels(Double(value))
}

public func faderWire(from level: FaderLevel) -> Float {
    switch level {
    case .minusInfinity: return digicoFaderMinusInfinityWire
    case .decibels(let db): return Float(db)
    }
}

public func raisedFader(_ level: FaderLevel, by stepDb: Double) -> FaderLevel {
    switch level {
    case .minusInfinity: return .decibels(Double(digicoFaderMinusInfinityWire) + stepDb)
    case .decibels(let db): return .decibels(db + stepDb)
    }
}

public func faderDbComparable(_ level: FaderLevel) -> Double {
    switch level {
    case .minusInfinity: return -Double.infinity
    case .decibels(let db): return db
    }
}
