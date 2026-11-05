import Foundation

/// Suggested starting targets. Ear / Haystack stay as user bank curves, not defaults.
public enum BuiltInTargets {
    public static let names: Set<String> = ["Flat", "Speech", "Music"]

    public static let presets: [CurvePreset] = [
        CurvePreset(name: "Flat", kind: .target, points: curve(flatNearly)),
        CurvePreset(name: "Speech", kind: .target, points: curve(speech)),
        CurvePreset(name: "Music", kind: .target, points: curve(music))
    ]

    /// Merge built-ins with bank presets. Bank entries with the same name replace the built-in.
    /// User curves such as Ear or Haystack appear after the three defaults.
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

    /// Near-flat reference. Tiny mid ripple only — no rising high-frequency slope.
    private static func flatNearly(_ hz: Double) -> Double {
        0.15 * sin(log2(max(hz, 20) / 500) * .pi)
    }

    /// Speech: less low end, flatter 125 Hz–8 kHz, no HF rise (intelligibility band).
    private static func speech(_ hz: Double) -> Double {
        if hz < 125 {
            // Less LF; settles to the flat speech band at 125 Hz.
            return -3.5 * (1 - log(max(hz, 20) / 20) / log(125.0 / 20.0))
        }
        if hz <= 8000 {
            // Near-flat through the scored speech band.
            return 0.1 * sin(log2(hz / 500) * .pi)
        }
        // Hold the 8 kHz level through the top octave — do not ask for more highs.
        return speech(8000)
    }

    /// Music: one low-frequency shelf of a few dB, then flat. Not a long tilt.
    private static func music(_ hz: Double) -> Double {
        let shelfDb = 3.0
        let corner = 100.0
        let flatBy = 200.0
        if hz <= corner { return shelfDb }
        if hz < flatBy {
            return shelfDb * (1 - log(hz / corner) / log(flatBy / corner))
        }
        return 0
    }
}
