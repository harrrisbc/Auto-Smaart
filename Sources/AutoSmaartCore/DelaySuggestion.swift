import Foundation

public enum DelaySuggestion: Equatable {
    case milliseconds(Double)
    case none
}

public func displayedDelayMs(_ rawMilliseconds: Double) -> Double {
    roundHalfAwayFromZero(rawMilliseconds, places: 1)
}

public func delaySuggestion(of capture: SmaartCapture) -> DelaySuggestion {
    if let finder = capture.delayFinderMs {
        return .milliseconds(finder)
    }
    guard let impulse = capture.impulse, impulse.sampleRate > 0, !impulse.samples.isEmpty else {
        return .none
    }
    var bestIndex = 0
    var bestAbsolute = abs(impulse.samples[0])
    for index in impulse.samples.indices.dropFirst() {
        let absolute = abs(impulse.samples[index])
        if absolute > bestAbsolute {
            bestAbsolute = absolute
            bestIndex = index
        }
    }
    return .milliseconds(Double(bestIndex) / impulse.sampleRate * 1000.0)
}
