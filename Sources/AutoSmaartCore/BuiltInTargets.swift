import Foundation

/// Starting target shapes for the curve list. Not cinema X-curve.
public enum BuiltInTargets {
    public static let names: Set<String> = ["Flat", "Speech", "Music", "Haystack"]

    public static let presets: [CurvePreset] = [
        CurvePreset(name: "Flat", kind: .target, points: curve { _ in 0 }),
        CurvePreset(name: "Speech", kind: .target, points: curve(speech)),
        CurvePreset(name: "Music", kind: .target, points: curve(music)),
        CurvePreset(name: "Haystack", kind: .target, points: curve(haystack))
    ]

    /// Merge built-ins with bank presets. Bank entries with the same name replace the built-in.
    public static func merge(bank: [CurvePreset]) -> [CurvePreset] {
        let byName = Dictionary(uniqueKeysWithValues: bank.map { ($0.name, $0) })
        var merged = presets.map { byName[$0.name] ?? $0 }
        for preset in bank where !names.contains(preset.name) {
            merged.append(preset)
        }
        return merged
    }

    private static let frequencies: [Double] = [
        20, 25, 30, 31.5, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630, 800,
        1000, 1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000, 12500, 16000, 20000
    ]

    private static func curve(_ dbAt: (Double) -> Double) -> [MagnitudePoint] {
        frequencies.map { MagnitudePoint(hz: $0, db: dbAt($0), phase: 0) }
    }

    /// Flat mids, small low boost.
    private static func speech(_ hz: Double) -> Double {
        if hz <= 80 { return 3 }
        if hz >= 300 { return 0 }
        return 3 * (1 - log(hz / 80) / log(300 / 80))
    }

    /// About 0.5–1 dB/octave downward tilt, +3 to +6 dB below ~100–200 Hz.
    private static func music(_ hz: Double) -> Double {
        if hz <= 100 { return 4.5 }
        if hz < 200 {
            return 4.5 * (200 - hz) / 100
        }
        let octaves = log2(hz / 200)
        return -0.75 * octaves
    }

    /// Flat above ~250 Hz; low rise to about +9 dB at 30 Hz.
    private static func haystack(_ hz: Double) -> Double {
        if hz <= 30 { return 9 }
        if hz >= 250 { return 0 }
        return 9 * (1 - log(hz / 30) / log(250.0 / 30.0))
    }
}
