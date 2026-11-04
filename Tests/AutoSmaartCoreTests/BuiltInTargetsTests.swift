import XCTest
@testable import AutoSmaartCore

final class BuiltInTargetsTests: XCTestCase {
    func testFourStartingShapes() {
        XCTAssertEqual(BuiltInTargets.presets.map(\.name), ["Flat", "Speech", "Music", "Haystack"])
        XCTAssertTrue(BuiltInTargets.presets.allSatisfy { $0.kind == .target })
        let flat = BuiltInTargets.presets[0].points
        XCTAssertFalse(flat.isEmpty)
        XCTAssertTrue(flat.allSatisfy { abs($0.db) < 0.001 })

        let speech = BuiltInTargets.presets[1].points
        XCTAssertGreaterThan(speech.first { $0.hz == 80 }?.db ?? 0, 2)
        XCTAssertEqual(speech.first { $0.hz == 1000 }?.db ?? -1, 0, accuracy: 0.001)

        let music = BuiltInTargets.presets[2].points
        XCTAssertEqual(music.first { $0.hz == 50 }?.db ?? 0, 4.5, accuracy: 0.001)
        XCTAssertLessThan(music.first { $0.hz == 2000 }?.db ?? 0, 0)

        let haystack = BuiltInTargets.presets[3].points
        XCTAssertEqual(haystack.first { $0.hz == 30 }?.db ?? 0, 9, accuracy: 0.2)
        XCTAssertEqual(haystack.first { $0.hz == 1000 }?.db ?? -1, 0, accuracy: 0.001)
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
