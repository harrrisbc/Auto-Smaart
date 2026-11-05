import XCTest
@testable import AutoSmaartCore

final class BuiltInTargetsTests: XCTestCase {
    func testFourStartingShapes() {
        XCTAssertEqual(BuiltInTargets.presets.map(\.name), ["Flat", "Speech", "Music", "Haystack"])
        XCTAssertTrue(BuiltInTargets.presets.allSatisfy { $0.kind == .target })

        let flat = BuiltInTargets.presets[0].points
        XCTAssertFalse(flat.isEmpty)
        // Not a ruler-flat line: mid and high differ, and HF rises for ear behavior.
        let mid = flat.first { $0.hz == 1000 }?.db ?? 0
        let high = flat.first { $0.hz == 10000 }?.db ?? 0
        XCTAssertGreaterThan(high - mid, 2)
        XCTAssertFalse(flat.allSatisfy { abs($0.db - mid) < 0.05 })

        let speech = BuiltInTargets.presets[1].points
        XCTAssertLessThan(speech.first { $0.hz == 50 }?.db ?? 0, -2)
        XCTAssertGreaterThan(speech.first { $0.hz == 1000 }?.db ?? -10, -1)
        let speechMid = speech.first { $0.hz == 1000 }?.db ?? 0
        let speechHigh = speech.first { $0.hz == 10000 }?.db ?? 0
        XCTAssertGreaterThan(speechHigh - speechMid, 3, "Speech must raise the highs, not sit flat on top")

        let music = BuiltInTargets.presets[2].points
        XCTAssertGreaterThan(music.first { $0.hz == 50 }?.db ?? 0, 2)
        XCTAssertLessThan(music.first { $0.hz == 2000 }?.db ?? 0, 0)

        let haystack = BuiltInTargets.presets[3].points
        XCTAssertGreaterThan(haystack.first { $0.hz == 40 }?.db ?? 0, 3)
        XCTAssertLessThan(abs(haystack.first { $0.hz == 1000 }?.db ?? 99), 1)
    }

    func testMergeKeepsBankCurvesAndLetsBankOverrideBuiltIn() {
        let bank = [
            CurvePreset(name: "Flat", kind: .target, points: [MagnitudePoint(hz: 1, db: 1, phase: 0)]),
            CurvePreset(name: "Show A", kind: .reference, points: [MagnitudePoint(hz: 2, db: 2, phase: 0)])
        ]
        let merged = BuiltInTargets.merge(bank: bank)
        XCTAssertEqual(merged.first { $0.name == "Flat" }?.points.first?.db, 1)
        XCTAssertEqual(merged.map(\.name), ["Flat", "Speech", "Music", "Haystack", "Show A"])
    }
}
