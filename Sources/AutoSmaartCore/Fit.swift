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
    return biquadMagnitudeDb(
        binHz: binHz,
        fs: fs,
        b0: b0, b1: b1, b2: b2,
        a0: a0, a1: a1, a2: a2
    )
}

/// RBJ low-shelf (S = 1). `cornerHz` is f0; `gainDb` is the shelf step.
func lowShelfMagnitudeDb(binHz: Double, cornerHz: Double, gainDb: Double) -> Double {
    let fs = 48000.0
    let a = pow(10.0, gainDb / 40.0)
    let omega0 = 2.0 * Double.pi * cornerHz / fs
    let cosine = cos(omega0)
    let sine = sin(omega0)
    let alpha = sine / 2.0 * sqrt(2.0)
    let twoSqrtAAlpha = 2.0 * sqrt(a) * alpha
    let b0 = a * ((a + 1) - (a - 1) * cosine + twoSqrtAAlpha)
    let b1 = 2 * a * ((a - 1) - (a + 1) * cosine)
    let b2 = a * ((a + 1) - (a - 1) * cosine - twoSqrtAAlpha)
    let a0 = (a + 1) + (a - 1) * cosine + twoSqrtAAlpha
    let a1 = -2 * ((a - 1) + (a + 1) * cosine)
    let a2 = (a + 1) + (a - 1) * cosine - twoSqrtAAlpha
    return biquadMagnitudeDb(
        binHz: binHz,
        fs: fs,
        b0: b0, b1: b1, b2: b2,
        a0: a0, a1: a1, a2: a2
    )
}

/// RBJ high-shelf (S = 1). `cornerHz` is f0; `gainDb` is the shelf step that holds.
func highShelfMagnitudeDb(binHz: Double, cornerHz: Double, gainDb: Double) -> Double {
    let fs = 48000.0
    let a = pow(10.0, gainDb / 40.0)
    let omega0 = 2.0 * Double.pi * cornerHz / fs
    let cosine = cos(omega0)
    let sine = sin(omega0)
    let alpha = sine / 2.0 * sqrt(2.0)
    let twoSqrtAAlpha = 2.0 * sqrt(a) * alpha
    let b0 = a * ((a + 1) + (a - 1) * cosine + twoSqrtAAlpha)
    let b1 = -2 * a * ((a - 1) + (a + 1) * cosine)
    let b2 = a * ((a + 1) + (a - 1) * cosine - twoSqrtAAlpha)
    let a0 = (a + 1) - (a - 1) * cosine + twoSqrtAAlpha
    let a1 = 2 * ((a - 1) - (a + 1) * cosine)
    let a2 = (a + 1) - (a - 1) * cosine - twoSqrtAAlpha
    return biquadMagnitudeDb(
        binHz: binHz,
        fs: fs,
        b0: b0, b1: b1, b2: b2,
        a0: a0, a1: a1, a2: a2
    )
}

func bandMagnitudeDb(binHz: Double, band: EqBand) -> Double {
    switch band.shape {
    case .peaking:
        return peakingMagnitudeDb(binHz: binHz, centerHz: band.hz, gainDb: band.gainDb, q: band.q)
    case .lowShelf:
        return lowShelfMagnitudeDb(binHz: binHz, cornerHz: band.hz, gainDb: band.gainDb)
    case .highShelf:
        return highShelfMagnitudeDb(binHz: binHz, cornerHz: band.hz, gainDb: band.gainDb)
    }
}

private func biquadMagnitudeDb(
    binHz: Double,
    fs: Double,
    b0: Double, b1: Double, b2: Double,
    a0: Double, a1: Double, a2: Double
) -> Double {
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

public func summedEqResponse(bands: [EqBand], at frequencies: [Double]) -> [MagnitudePoint] {
    guard !bands.isEmpty else { return [] }
    return frequencies.map { hz in
        let db = bands.reduce(0.0) { partial, band in
            partial + bandMagnitudeDb(binHz: hz, band: band)
        }
        return MagnitudePoint(hz: hz, db: db, phase: 0)
    }
}

public func summedEqResponse(bands: [EqBand], samples: Int = 128) -> [MagnitudePoint] {
    guard !bands.isEmpty, samples > 1 else { return [] }
    let logStart = log10(20.0)
    let logEnd = log10(20000.0)
    let frequencies = (0..<samples).map { index -> Double in
        let t = Double(index) / Double(samples - 1)
        return pow(10, logStart + (logEnd - logStart) * t)
    }
    return summedEqResponse(bands: bands, at: frequencies)
}

/// Live-sound peaking bells earn their place in the controlled band.
/// Below ~125 Hz is coupling / a shelf job; the top octave is air / coherence.
public let fitBandLowHz = 125.0
public let fitBandHighHz = 8000.0

public func fitEq(measurement: [MagnitudePoint], preset: [MagnitudePoint]) -> FitResult {
    let presetPoints = uniquePreset(preset)
    guard let first = presetPoints.first, let last = presetPoints.last else { return .noOverlap }

    let fullBins = measurement
        .filter { $0.hz >= 20 && $0.hz <= 20000 }
        .sorted { $0.hz < $1.hz }
    var fullDeviation: [(hz: Double, db: Double)] = []
    for bin in fullBins {
        guard let presetDb = interpolate(hz: bin.hz, preset: presetPoints, first: first.hz, last: last.hz) else { continue }
        fullDeviation.append((bin.hz, bin.db - presetDb))
    }
    if fullDeviation.isEmpty { return .noOverlap }

    var bands: [EqBand] = []
    if let shelf = detectLowShelf(in: fullDeviation) {
        bands.append(shelf)
        for index in fullDeviation.indices {
            fullDeviation[index].db += bandMagnitudeDb(binHz: fullDeviation[index].hz, band: shelf)
        }
    }
    if let shelf = detectHighShelf(in: fullDeviation, nextIndex: bands.count + 1) {
        bands.append(shelf)
        for index in fullDeviation.indices {
            fullDeviation[index].db += bandMagnitudeDb(binHz: fullDeviation[index].hz, band: shelf)
        }
    }

    var deviation = fullDeviation.filter { $0.hz >= fitBandLowHz && $0.hz <= fitBandHighHz }
    if deviation.isEmpty {
        return bands.isEmpty ? .noOverlap : .bands(bands)
    }
    if (deviation.map { abs($0.db) }.max() ?? 0) <= 1.0 {
        return .bands(bands)
    }

    var claimed = Array(repeating: false, count: deviation.count)
    while bands.count < 8 {
        guard let chosen = nextPeakIndex(deviation: deviation, claimed: claimed) else { break }
        let center = deviation[chosen]
        if abs(center.db) <= 1.0 { break }
        if bands.contains(where: { $0.shape == .peaking && bandCovers(hz: center.hz, band: $0) }) {
            claimed[chosen] = true
            continue
        }
        // A peaking bell cannot follow a shelf — do not plant a narrow spike on
        // the leftover knee when a shelf already owns that end of the band.
        if bands.contains(where: { $0.shape == .lowShelf }) && center.hz < 250 {
            claimed[chosen] = true
            continue
        }
        if bands.contains(where: { $0.shape == .highShelf }) && center.hz > 1500 {
            claimed[chosen] = true
            continue
        }
        let gain = roundHalfAwayFromZero(min(18.0, max(-18.0, -center.db)), places: 1)
        let half = abs(center.db) / 2.0
        var low = chosen
        while low > 0
            && abs(deviation[low - 1].db) >= half
            && deviation[low - 1].db * center.db > 0
        {
            low -= 1
        }
        var high = chosen
        while high < deviation.count - 1
            && abs(deviation[high + 1].db) >= half
            && deviation[high + 1].db * center.db > 0
        {
            high += 1
        }
        let q = quality(lowHz: deviation[low].hz, highHz: deviation[high].hz)
        var claimLow = chosen
        while claimLow > 0
            && abs(deviation[claimLow - 1].db) > 1.0
            && deviation[claimLow - 1].db * center.db > 0
        {
            claimLow -= 1
        }
        var claimHigh = chosen
        while claimHigh < deviation.count - 1
            && abs(deviation[claimHigh + 1].db) > 1.0
            && deviation[claimHigh + 1].db * center.db > 0
        {
            claimHigh += 1
        }
        let band = EqBand(
            index: bands.count + 1,
            hz: center.hz,
            gainDb: gain,
            q: q,
            shape: .peaking
        )
        bands.append(band)
        for index in deviation.indices {
            deviation[index].db += bandMagnitudeDb(binHz: deviation[index].hz, band: band)
        }
        for index in claimLow...claimHigh {
            claimed[index] = true
        }
    }
    return .bands(bands)
}

/// One low shelf when the LF error is a broad step, not a resonance.
func detectLowShelf(in deviation: [(hz: Double, db: Double)]) -> EqBand? {
    let lows = deviation.filter { $0.hz <= 100 }
    let mids = deviation.filter { $0.hz >= 400 && $0.hz <= 2000 }
    guard lows.count >= 2, mids.count >= 2 else { return nil }
    let lowMean = lows.map(\.db).reduce(0, +) / Double(lows.count)
    let midMean = mids.map(\.db).reduce(0, +) / Double(mids.count)
    let delta = lowMean - midMean
    guard abs(delta) > 1.5 else { return nil }
    let midSpread = (mids.map(\.db).max() ?? 0) - (mids.map(\.db).min() ?? 0)
    guard midSpread <= 3.0 else { return nil }

    let gain = roundHalfAwayFromZero(min(18.0, max(-18.0, -delta)), places: 1)
    guard abs(gain) >= 1.5 else { return nil }

    let halfLevel = midMean + delta / 2.0
    let sorted = deviation.sorted { $0.hz < $1.hz }
    var corner = 100.0
    for index in 0..<(sorted.count - 1) where sorted[index].hz <= 400 {
        let left = sorted[index]
        let right = sorted[index + 1]
        let crosses = (left.db - halfLevel) * (right.db - halfLevel) <= 0
        if crosses && left.db != right.db {
            let t = (halfLevel - left.db) / (right.db - left.db)
            corner = left.hz * pow(right.hz / left.hz, t)
            break
        }
    }
    corner = min(250.0, max(40.0, corner))
    return EqBand(index: 1, hz: roundHalfAwayFromZero(corner, places: 0), gainDb: gain, q: 0.71, shape: .lowShelf)
}

/// One high shelf when the HF error is a broad step that holds, not a resonance.
func detectHighShelf(in deviation: [(hz: Double, db: Double)], nextIndex: Int) -> EqBand? {
    let mids = deviation.filter { $0.hz >= 400 && $0.hz <= 1000 }
    let highs = deviation.filter { $0.hz >= 4000 && $0.hz <= 8000 }
    guard mids.count >= 2, highs.count >= 2 else { return nil }
    let midMean = mids.map(\.db).reduce(0, +) / Double(mids.count)
    let highMean = highs.map(\.db).reduce(0, +) / Double(highs.count)
    let delta = highMean - midMean
    guard abs(delta) > 1.5 else { return nil }
    let midSpread = (mids.map(\.db).max() ?? 0) - (mids.map(\.db).min() ?? 0)
    let highSpread = (highs.map(\.db).max() ?? 0) - (highs.map(\.db).min() ?? 0)
    guard midSpread <= 3.0, highSpread <= 2.5 else { return nil }

    let gain = roundHalfAwayFromZero(min(18.0, max(-18.0, -delta)), places: 1)
    guard abs(gain) >= 1.5 else { return nil }

    let halfLevel = midMean + delta / 2.0
    let sorted = deviation.sorted { $0.hz < $1.hz }
    var corner = 2000.0
    for index in 0..<(sorted.count - 1) where sorted[index].hz >= 800 && sorted[index].hz <= 6000 {
        let left = sorted[index]
        let right = sorted[index + 1]
        let crosses = (left.db - halfLevel) * (right.db - halfLevel) <= 0
        if crosses && left.db != right.db {
            let t = (halfLevel - left.db) / (right.db - left.db)
            corner = left.hz * pow(right.hz / left.hz, t)
            break
        }
    }
    corner = min(6000.0, max(800.0, corner))
    return EqBand(
        index: nextIndex,
        hz: roundHalfAwayFromZero(corner, places: 0),
        gainDb: gain,
        q: 0.71,
        shape: .highShelf
    )
}

/// Largest unclaimed |deviation|; ties go to the lower frequency.
private func nextPeakIndex(deviation: [(hz: Double, db: Double)], claimed: [Bool]) -> Int? {
    var best: Int?
    for index in deviation.indices where !claimed[index] {
        guard let current = best else {
            best = index
            continue
        }
        let left = abs(deviation[index].db)
        let right = abs(deviation[current].db)
        if left > right || (left == right && deviation[index].hz < deviation[current].hz) {
            best = index
        }
    }
    return best
}

/// True when `hz` sits inside the peaking band's effective coverage.
func bandCovers(hz: Double, band: EqBand) -> Bool {
    guard band.shape == .peaking, band.hz > 0, hz > 0, band.q > 0 else { return false }
    let octaves = abs(log2(hz / band.hz))
    let halfBandwidthOctaves = max(0.5 / band.q, 0.25)
    return octaves <= halfBandwidthOctaves
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
