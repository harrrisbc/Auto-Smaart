import Foundation

public enum NotchDecision: Equatable {
    case write(EqBand)
    case deepen(EqBand)
    case bandCap
    case floorReached(EqBand)
}

public func centsDistance(_ aHz: Double, _ bHz: Double) -> Double {
    1200.0 * abs(log2(aHz / bHz))
}

public func decideNotch(peakHz: Double, bands: [EqBand]) -> NotchDecision {
    let matches = bands
        .map { (band: $0, cents: centsDistance(peakHz, $0.hz)) }
        .filter { $0.cents <= 50 }
        .sorted { lhs, rhs in
            if abs(lhs.cents - rhs.cents) <= 1e-9 { return lhs.band.index < rhs.band.index }
            return lhs.cents < rhs.cents
        }
    if let match = matches.first?.band {
        if match.gainDb <= -18.0 {
            return .floorReached(match)
        }
        let nextGain = max(-18.0, match.gainDb - 3.0)
        return .deepen(EqBand(index: match.index, hz: match.hz, gainDb: nextGain, q: match.q))
    }
    let used = Set(bands.map(\.index))
    guard let free = (1...8).first(where: { !used.contains($0) }) else {
        return .bandCap
    }
    return .write(EqBand(index: free, hz: peakHz, gainDb: -3.0, q: 16.0))
}
