import XCTest
@testable import AutoSmaartCore

final class CurveBankTests: XCTestCase {
    func testStoreRecallReplaceBlankAndRelaunch() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let bank = CurveBank(fileURL: url)
        let trace = [MagnitudePoint(hz: 100, db: -2, phase: 3)]
        let target = [MagnitudePoint(hz: 100, db: 0, phase: 9)]
        XCTAssertThrowsError(try bank.store(name: "   ", kind: .reference, points: trace)) { error in
            XCTAssertEqual(error as? CurveBankError, .blankName)
        }
        XCTAssertTrue(bank.presets.isEmpty)
        try bank.store(name: " Main ", kind: .reference, points: trace)
        try bank.store(name: "Main target", kind: .target, points: target)
        XCTAssertEqual(bank.presets.map(\.name), ["Main", "Main target"])
        try bank.store(name: "Main", kind: .target, points: target)
        XCTAssertEqual(bank.presets.count, 1 + 1)
        XCTAssertEqual(bank.presets[0].kind, .target)
        XCTAssertEqual(bank.presets[0].points, target)
        let reloaded = CurveBank(fileURL: url)
        try reloaded.reload()
        XCTAssertEqual(reloaded.presets, bank.presets)
    }
}
