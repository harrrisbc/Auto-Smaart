import XCTest
@testable import AutoSmaartCore

final class BuiltInTargetsTests: XCTestCase {
    func testThreeSuggestedDefaults() {
        XCTAssertEqual(BuiltInTargets.presets.map(\.name), ["Flat", "Speech", "Music"])
        XCTAssertTrue(BuiltInTargets.presets.allSatisfy { $0.kind == .target })
        XCTAssertFalse(BuiltInTargets.names.contains("Haystack"))
        XCTAssertFalse(BuiltInTargets.names.contains("Ear"))

        let flat = BuiltInTargets.presets[0].points
        XCTAssertFalse(flat.isEmpty)
        let flatMid = flat.first { $0.hz == 1000 }?.db ?? 0
        let flatHigh = flat.first { $0.hz == 10000 }?.db ?? 0
        XCTAssertLessThan(abs(flatHigh - flatMid), 1, "Flat must not rise through the highs")
        XCTAssertTrue(flat.allSatisfy { abs($0.db) < 1 })

        let speech = BuiltInTargets.presets[1].points
        XCTAssertLessThan(speech.first { $0.hz == 50 }?.db ?? 0, -1, "Speech has less low end")
        let speech125 = speech.first { $0.hz == 125 }?.db ?? 99
        let speech1k = speech.first { $0.hz == 1000 }?.db ?? 99
        let speech8k = speech.first { $0.hz == 8000 }?.db ?? 99
        let speech16k = speech.first { $0.hz == 16000 }?.db ?? 99
        XCTAssertLessThan(abs(speech1k - speech125), 1, "Speech stays flatter 125 Hz–8 kHz")
        XCTAssertLessThan(abs(speech8k - speech1k), 1)
        XCTAssertLessThan(abs(speech16k - speech8k), 0.05, "Speech must not rise through the top octave")

        let music = BuiltInTargets.presets[2].points
        XCTAssertGreaterThan(music.first { $0.hz == 50 }?.db ?? 0, 2)
        XCTAssertLessThan(music.first { $0.hz == 50 }?.db ?? 99, 6, "a few dB shelf, not a huge tilt")
        XCTAssertLessThan(abs(music.first { $0.hz == 1000 }?.db ?? 99), 0.5)
        XCTAssertLessThan(abs(music.first { $0.hz == 10000 }?.db ?? 99), 0.5)
        let musicLow = music.first { $0.hz == 40 }?.db ?? 0
        let musicHigh = music.first { $0.hz == 10000 }?.db ?? 0
        XCTAssertLessThan(musicLow - musicHigh, 8, "not a +24 dB lows-to-highs tilt")
    }

    func testMergeKeepsBankCurvesAndLetsBankOverrideBuiltIn() {
        let bank = [
            CurvePreset(name: "Flat", kind: .target, points: [MagnitudePoint(hz: 1, db: 1, phase: 0)]),
            CurvePreset(name: "Haystack", kind: .target, points: [MagnitudePoint(hz: 40, db: 5, phase: 0)]),
            CurvePreset(name: "Ear", kind: .reference, points: [MagnitudePoint(hz: 2, db: 2, phase: 0)]),
            CurvePreset(name: "Show A", kind: .reference, points: [MagnitudePoint(hz: 3, db: 3, phase: 0)])
        ]
        let merged = BuiltInTargets.merge(bank: bank)
        XCTAssertEqual(merged.first { $0.name == "Flat" }?.points.first?.db, 1)
        XCTAssertEqual(merged.map(\.name), ["Flat", "Speech", "Music", "Haystack", "Ear", "Show A"])
        XCTAssertFalse(BuiltInTargets.presets.contains { $0.name == "Haystack" })
    }
}
