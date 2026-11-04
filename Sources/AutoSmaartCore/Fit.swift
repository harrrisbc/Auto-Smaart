import Foundation

public enum FitResult: Equatable {
    case bands([EqBand])
    case noOverlap
}

public func formatFrequency(_ hz: Double) -> String {
    if hz < 1000 {
        return "\(Int(roundHalfAwayFromZero(hz, places: 0))) Hz"
    }
    let kilohertz = roundHalfAwayFromZero(hz / 1000.0, places: 2)
    return String(format: "%.2f kHz", kilohertz)
}

func peakingMagnitudeDb(binHz: Double, centerHz: Double, gainDb: Double, q: Double) -> Double {
    let fs = 48000.0
    let a = pow(10.0, gainDb / 40.0)
    let omega0 = 2.0 * Double.pi * centerHz / fs
    let alpha = sin(omega0) / (2.0 * q)
    let b0 = 1.0 + alpha * a
    let b1 = -2.0 * cos(omega0)
    let b2 = 1.0 - alpha * a
    let a0 = 1.0 + alpha / a
    let a1 = -2.0 * cos(omega0)
    let a2 = 1.0 - alpha / a
    let omega = 2.0 * Double.pi * binHz / fs
    let cosine1 = cos(omega)
    let sine1 = sin(omega)
    let cosine2 = cos(2.0 * omega)
    let sine2 = sin(2.0 * omega)
    let numeratorReal = b0 + b1 * cosine1 + b2 * cosine2
    let numeratorImag = -b1 * sine1 - b2 * sine2
    let denominatorReal = a0 + a1 * cosine1 + a2 * cosine2
    let denominatorImag = -a1 * sine1 - a2 * sine2
    let numerator = hypot(numeratorReal, numeratorImag)
    let denominator = hypot(denominatorReal, denominatorImag)
    return 20.0 * log10(numerator / denominator)
}

public func fitEq(measurement: [MagnitudePoint], preset: [MagnitudePoint]) -> FitResult {
    let bins = measurement.filter { $0.hz >= 20 && $0.hz <= 20000 }.sorted { $0.hz < $1.hz }
    let presetPoints = uniquePreset(preset)
    guard let first = presetPoints.first, let last = presetPoints.last else { return .noOverlap }
    var deviation: [(hz: Double, db: Double)] = []
    for bin in bins {
        guard let presetDb = interpolate(hz: bin.hz, preset: presetPoints, first: first.hz, last: last.hz) else { continue }
        deviation.append((bin.hz, bin.db - presetDb))
    }
    if deviation.isEmpty { return .noOverlap }
    if (deviation.map { abs($0.db) }.max() ?? 0) <= 1.0 { return .bands([]) }
    var bands: [EqBand] = []
    while bands.count < 8 {
        let chosen = deviation.indices.max { lhs, rhs in
            let left = abs(deviation[lhs].db)
            let right = abs(deviation[rhs].db)
            if left == right { return deviation[lhs].hz > deviation[rhs].hz }
            return left < right
        }!
        let center = deviation[chosen]
        if abs(center.db) <= 1.0 { break }
        let gain = roundHalfAwayFromZero(min(18.0, max(-18.0, -center.db)), places: 1)
        let half = abs(center.db) / 2.0
        var low = chosen
        while low > 0 && abs(deviation[low - 1].db) >= half { low -= 1 }
        var high = chosen
        while high < deviation.count - 1 && abs(deviation[high + 1].db) >= half { high += 1 }
        let q = quality(lowHz: deviation[low].hz, highHz: deviation[high].hz)
        bands.append(EqBand(index: bands.count + 1, hz: center.hz, gainDb: gain, q: q))
        for index in deviation.indices {
            deviation[index].db -= peakingMagnitudeDb(binHz: deviation[index].hz, centerHz: center.hz, gainDb: gain, q: q)
        }
    }
    return .bands(bands)
}

private func uniquePreset(_ preset: [MagnitudePoint]) -> [MagnitudePoint] {
    var firstIndex: [Double: Int] = [:]
    for (index, point) in preset.enumerated() where firstIndex[point.hz] == nil {
        firstIndex[point.hz] = index
    }
    return preset.enumerated()
        .filter { firstIndex[$0.element.hz] == $0.offset }
        .map(\.element)
        .sorted { $0.hz < $1.hz }
}

private func interpolate(hz: Double, preset: [MagnitudePoint], first: Double, last: Double) -> Double? {
    if hz < first || hz > last { return nil }
    if let exact = preset.first(where: { $0.hz == hz }) { return exact.db }
    for index in 0..<(preset.count - 1) {
        let left = preset[index]
        let right = preset[index + 1]
        if hz >= left.hz && hz <= right.hz {
            let t = (log(hz) - log(left.hz)) / (log(right.hz) - log(left.hz))
            return left.db + t * (right.db - left.db)
        }
    }
    return nil
}

private func quality(lowHz: Double, highHz: Double) -> Double {
    if lowHz == highHz { return 4.0 }
    let n = log2(highHz / lowHz)
    let raw = sqrt(pow(2.0, n)) / (pow(2.0, n) - 1.0)
    return roundHalfAwayFromZero(min(20.0, max(0.10, raw)), places: 2)
}
