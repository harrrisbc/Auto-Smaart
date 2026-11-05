import XCTest
import SwiftUI
import AutoSmaartCore
@testable import AutoSmaartUI
@testable import AutoSmaartPass

@MainActor
final class ShellTests: XCTestCase {
    func testMetricsAndColors() {
        XCTAssertEqual(ThemeMetrics.windowWidth, 1440)
        XCTAssertEqual(ThemeMetrics.windowHeight, 900)
        XCTAssertEqual(ThemeMetrics.titleBar, 56)
        XCTAssertEqual(ThemeMetrics.rail, 220)
        XCTAssertEqual(ThemeMetrics.bottomBar, 64)
        XCTAssertEqual(Theme.backgroundHex, "0a0a0a")
        XCTAssertEqual(Theme.textHex, "ffffff")
        XCTAssertEqual(Theme.secondaryHex, "a3a3a3")
        XCTAssertEqual(Theme.goldHex, "a78b71")
        XCTAssertEqual(Theme.lightGoldHex, "c9b8a0")
        XCTAssertEqual(Theme.hoverGoldHex, "e8d5b7")
        XCTAssertEqual(Theme.liveHex, "4ade80")
        XCTAssertEqual(Theme.beforeHex, "a78b71")
        XCTAssertEqual(Theme.afterHex, "e8d5b7")
    }

    func testScreensRenderThePresenterCopy() throws {
        let point = MagnitudePoint(hz: 1000, db: -3, phase: 0)
        let (pass, _, _, _) = makePass(traces: [capture(magnitude: [point], finder: 12.35)])
        try prepare(pass, points: [point])
        let pick = PickView(controller: pass)
        let settings = SettingsView(controller: pass)
        let delay = DelayView(controller: pass)
        let eq = EQView(controller: pass)
        let compare = CompareView(controller: pass)
        _ = pick.body
        _ = settings.body
        _ = delay.body
        _ = eq.body
        _ = compare.body
        XCTAssertTrue(pass.state.presets.map(\.name).contains("Flat"))
        XCTAssertEqual(pass.state.presets.prefix(3).map(\.name), ["Flat", "Speech", "Music"])
        pass.readTrace()
        let shell = ShellView(controller: pass)
        _ = shell.body
        pass.matrixPickerOpen = true
        _ = shell.body
        pass.matrixPickerOpen = false
        pass.presetPickerOpen = true
        _ = shell.body
        pass.presetPickerOpen = false
        pass.settingsOpen = true
        _ = shell.body
        XCTAssertEqual(pass.state.step, .delay)
        let plot = MagnitudePlot(before: [point], after: nil, bands: [
            EqBand(index: 1, hz: 1000, gainDb: -3, q: 4)
        ])
        _ = plot.body
        XCTAssertEqual(
            BandHoverText.readout(EqBand(index: 2, hz: 1000, gainDb: -3, q: 16)),
            "1.00 kHz · Q 16.00 · -3.0 dB"
        )
        let thumb = CurveThumb(points: BuiltInTargets.presets[0].points, selected: true)
        _ = thumb.body
    }

    func testUISourceDoesNotHardcodeTheDraftNumbers() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent("Sources/AutoSmaartUI")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let source = try files.filter { $0.pathExtension == "swift" }.map { try String(contentsOf: $0) }.joined(separator: "\n")
        for forbidden in ["18.6", "Suggested from the Main target", "unlock your mix", "CGWindowListCreateImage", "screencapture"] {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
        XCTAssertTrue(source.contains("PassPresenter"))
        XCTAssertFalse(source.contains("fitEq"))
        XCTAssertFalse(source.contains("/sd/Matrix_Outputs"))
    }
}
