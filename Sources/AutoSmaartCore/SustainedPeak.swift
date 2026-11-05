import Foundation

public struct PeakFrame: Equatable {
    public var binIndex: Int
    public var hz: Double
    public var magnitudeDb: Double
    public init(binIndex: Int, hz: Double, magnitudeDb: Double) {
        self.binIndex = binIndex
        self.hz = hz
        self.magnitudeDb = magnitudeDb
    }
}

public struct SustainedPeak: Equatable {
    public var binIndex: Int
    public var hz: Double
    public var magnitudeDb: Double
    public init(binIndex: Int, hz: Double, magnitudeDb: Double) {
        self.binIndex = binIndex
        self.hz = hz
        self.magnitudeDb = magnitudeDb
    }
}

public func peakFrame(in spectrum: [MagnitudePoint]) -> PeakFrame? {
    let kept = spectrum.enumerated().filter { $0.element.hz >= 100 && $0.element.hz <= 8000 }
    guard !kept.isEmpty else { return nil }
    let magnitudes = kept.map(\.element.db)
    let sorted = magnitudes.sorted()
    let median: Double
    if sorted.count % 2 == 0 {
        median = (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2.0
    } else {
        median = sorted[sorted.count / 2]
    }
    var best = 0
    for index in kept.indices.dropFirst() {
        let left = kept[best].element
        let right = kept[index].element
        if right.db > left.db || (right.db == left.db && right.hz < left.hz) {
            best = index
        }
    }
    let candidate = kept[best]
    guard candidate.element.db >= median + 10.0 else { return nil }
    // Side lobe = quieter bins within 3 dB. Equal-loud rivals stay out so a
    // loudness tie at another frequency does not widen the Q estimate.
    var low = best
    while low > 0 {
        let neighbor = kept[low - 1].element
        let drop = candidate.element.db - neighbor.db
        guard drop > 0, drop <= 3.0 else { break }
        low -= 1
    }
    var high = best
    while high < kept.count - 1 {
        let neighbor = kept[high + 1].element
        let drop = candidate.element.db - neighbor.db
        guard drop > 0, drop <= 3.0 else { break }
        high += 1
    }
    let fLo = kept[low].element.hz
    let fHi = kept[high].element.hz
    let narrow: Bool
    if fLo == fHi {
        narrow = true
    } else {
        let n = log2(fHi / fLo)
        let q = sqrt(pow(2.0, n)) / (pow(2.0, n) - 1.0)
        narrow = q >= 10.0
    }
    guard narrow else { return nil }
    return PeakFrame(binIndex: candidate.offset, hz: candidate.element.hz, magnitudeDb: candidate.element.db)
}

public final class SustainedPeakDetector {
    private let requiredFrames: Int
    private var streakBin: Int?
    private var streakHz: Double?
    private var magnitudes: [Double] = []

    public init(requiredFrames: Int = 8) {
        self.requiredFrames = requiredFrames
    }

    public func reset() {
        streakBin = nil
        streakHz = nil
        magnitudes = []
    }

    public func push(_ spectrum: [MagnitudePoint]) -> SustainedPeak? {
        guard let frame = peakFrame(in: spectrum) else {
            reset()
            return nil
        }
        // Same RTA bin means same frequency on a fixed grid. Tests also change
        // hz at a reused array index — treat hz change as a new streak.
        if streakBin != frame.binIndex || streakHz != frame.hz {
            streakBin = frame.binIndex
            streakHz = frame.hz
            magnitudes = [frame.magnitudeDb]
        } else {
            magnitudes.append(frame.magnitudeDb)
        }
        guard magnitudes.count >= requiredFrames, let bin = streakBin else { return nil }
        let mean = magnitudes.reduce(0, +) / Double(magnitudes.count)
        let peak = SustainedPeak(binIndex: bin, hz: frame.hz, magnitudeDb: mean)
        reset()
        return peak
    }
}
