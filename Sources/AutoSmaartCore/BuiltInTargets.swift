import Foundation

/// Starting target shapes for the curve list. Speaker-realistic; not cinema X-curve.
public enum BuiltInTargets {
    public static let names: Set<String> = ["Flat", "Speech", "Music", "Haystack"]

    public static let presets: [CurvePreset] = [
        CurvePreset(name: "Flat", kind: .target, points: curve(flatNearly)),
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

    /// Nearly-flat reference that is visibly not a ruler, with a rising HF tilt for ear behavior
    /// (more energy in the highs).
    private static func flatNearly(_ hz: Double) -> Double {
        // Soft mid undulation so the graph is not a perfect line.
        let ripple = 0.35 * sin(log2(max(hz, 20) / 200) * .pi)
        if hz <= 1000 {
            return ripple
        }
        // Rising high-frequency tilt: ~+4 dB by 10 kHz, ~+5.5 dB by 16 kHz.
        let octaves = log2(hz / 1000)
        return ripple + 1.6 * octaves
    }

    /// Speech: less bass, flatter through the mid / presence band.
    private static func speech(_ hz: Double) -> Double {
        if hz <= 80 { return -5 }
        if hz < 250 {
            return -5 + 5 * (log(hz / 80) / log(250.0 / 80.0))
        }
        if hz < 4000 { return 0.2 * sin(log2(hz / 500) * .pi) }
        // Mild presence, not a loudspeaker "flat" shelf.
        return 0.5
    }

    /// Music: low lift with a gentle downward tilt through the band.
    private static func music(_ hz: Double) -> Double {
        if hz <= 80 { return 4 }
        if hz < 200 {
            return 4 * (1 - log(hz / 80) / log(200.0 / 80.0))
        }
        // ~0.7 dB/octave downward from 200 Hz.
        return -0.7 * log2(hz / 200)
    }

    /// Low haystack: modest bass rise that settles by ~250 Hz.
    private static func haystack(_ hz: Double) -> Double {
        if hz <= 40 { return 5 }
        if hz >= 250 { return 0.15 * sin(log2(hz / 500) * .pi) }
        return 5 * (1 - log(hz / 40) / log(250.0 / 40.0))
    }
}
