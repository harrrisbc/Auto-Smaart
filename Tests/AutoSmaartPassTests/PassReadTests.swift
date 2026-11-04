import XCTest
import AutoSmaartCore
@testable import AutoSmaartPass

@MainActor
final class PassReadTests: XCTestCase {
    func testTwelveBlankOutputsAndNoOSCOnRead() throws {
        let point = MagnitudePoint(hz: 1000, db: -3, phase: 15)
        let (pass, _, link, directory) = makePass(traces: [capture(magnitude: [point], finder: 12.35)])
        XCTAssertEqual(pass.state.outputs.count, 12)
        XCTAssertEqual(pass.state.outputs.map(\.index), Array(1...12))
        XCTAssertTrue(pass.state.outputs.allSatisfy { $0.displayName.isEmpty && $0.lastWrite == nil && $0.delaySnapshot == nil })
        XCTAssertEqual(pass.state.host, "")
        XCTAssertEqual(pass.state.port, "")
        let bank = CurveBank(fileURL: directory.appendingPathComponent("bank.json"))
        try bank.store(name: "Main", kind: .reference, points: [point])
        pass.reloadFromStores()
        pass.setHost("10.0.0.8")
        pass.setPort("8000")
        pass.selectOutput(1)
        pass.recall(name: "Main")
        pass.readTrace()
        pass.back()
        pass.openRail(.delay)
        pass.openRail(.eq)
        pass.openRail(.compare)
        XCTAssertTrue(link.log.isEmpty)
        XCTAssertEqual(pass.state.step, .delay)
        XCTAssertEqual(pass.state.displayedDelayMs, 12.4)
        XCTAssertEqual(pass.state.latestMagnitude?.first?.phase, 15)
        XCTAssertFalse(pass.canOpen(.eq))
        XCTAssertNil(pass.state.bands)
    }

    func testNeitherFixtureStaysOnPick() throws {
        let url = Bundle.module.url(forResource: "neither", withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: "neither", withExtension: "json")
        let neither = try JSONDecoder().decode(SmaartCapture.self, from: Data(contentsOf: try XCTUnwrap(url)))
        let (pass, _, link, _) = makePass(traces: [neither])
        try prepare(pass, points: neither.magnitude)
        pass.readTrace()
        XCTAssertEqual(pass.state.step, .pick)
        XCTAssertEqual(pass.state.notice, .noDelaySuggestion)
        XCTAssertEqual(pass.state.latestMagnitude, neither.magnitude)
        XCTAssertTrue(link.log.isEmpty)
        XCTAssertFalse(pass.canOpen(.delay))
    }

    func testMissingMagnitudeStaysOnPickWithoutASuggestion() throws {
        let url = Bundle.module.url(forResource: "no-magnitude", withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: "no-magnitude", withExtension: "json")
        let missing = try JSONDecoder().decode(SmaartCapture.self, from: Data(contentsOf: try XCTUnwrap(url)))
        let (pass, _, link, _) = makePass(traces: [missing])
        try prepare(pass, points: [MagnitudePoint(hz: 100, db: 0, phase: 0)])
        pass.readTrace()
        XCTAssertEqual(pass.state.notice, .noSmaartTrace)
        XCTAssertEqual(pass.state.step, .pick)
        XCTAssertNil(pass.state.latestMagnitude)
        XCTAssertNil(pass.state.suggestionRaw)
        XCTAssertTrue(link.log.isEmpty)
    }

    func testStoreTargetStoreTraceBlankNameAndReplace() throws {
        let point = MagnitudePoint(hz: 100, db: 0, phase: 1)
        let target = [MagnitudePoint(hz: 100, db: -1, phase: 0)]
        let (pass, _, _, directory) = makePass(traces: [capture(magnitude: [point], finder: nil)], target: target)
        pass.setDraftName("   ")
        pass.storeTarget()
        XCTAssertTrue(pass.state.presets.isEmpty)
        pass.setDraftName("Main target")
        pass.storeTarget()
        XCTAssertEqual(pass.state.presets.first?.kind, .target)
        pass.storeTrace()
        XCTAssertEqual(pass.state.notice, .noSmaartTrace)
        try prepare(pass, points: [point])
        pass.readTrace()
        pass.setDraftName("Main")
        pass.storeTrace()
        XCTAssertEqual(pass.state.presets.first { $0.name == "Main" }?.kind, .reference)
        pass.setDraftName("Main")
        pass.storeTarget()
        XCTAssertEqual(pass.state.presets.filter { $0.name == "Main" }.count, 1)
        XCTAssertEqual(pass.state.presets.first { $0.name == "Main" }?.kind, .target)
        let reloaded = CurveBank(fileURL: directory.appendingPathComponent("bank.json"))
        try reloaded.reload()
        XCTAssertEqual(reloaded.presets.first { $0.name == "Main" }?.kind, .target)
    }

    func testRecallOfTheCurrentPresetDoesNotResetThePass() throws {
        let point = MagnitudePoint(hz: 100, db: 0, phase: 0)
        let (pass, _, _, _) = makePass(traces: [capture(magnitude: [point], finder: 4)])
        try prepare(pass, points: [point])
        pass.readTrace()
        XCTAssertEqual(pass.state.step, .delay)
        pass.back()
        pass.recall(name: "Main")
        XCTAssertEqual(pass.state.suggestionRaw, 4)
        pass.recall(name: "Other")
        XCTAssertEqual(pass.state.passPresetName, "Other")
        XCTAssertEqual(pass.state.step, .pick)
        XCTAssertNil(pass.state.suggestionRaw)
    }

    func testChangingOutputStartsAnotherPassWithoutOSC() throws {
        let point = MagnitudePoint(hz: 100, db: 0, phase: 0)
        let (pass, _, link, _) = makePass(traces: [capture(magnitude: [point], finder: 4)])
        try prepare(pass, points: [point])
        pass.readTrace()
        pass.selectOutput(2)
        XCTAssertEqual(pass.state.step, .pick)
        XCTAssertNil(pass.state.suggestionRaw)
        XCTAssertEqual(pass.state.selectedOutput, 2)
        XCTAssertTrue(link.log.isEmpty)
    }

    func testNoTargetCurveNotice() {
        let (pass, _, _, _) = makePass(traces: [])
        pass.setDraftName("Missing")
        pass.storeTarget()
        XCTAssertEqual(pass.state.notice, .noSmaartTarget)
        XCTAssertTrue(pass.state.presets.isEmpty)
    }
}
