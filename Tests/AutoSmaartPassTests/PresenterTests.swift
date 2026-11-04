import XCTest
import AutoSmaartCore
@testable import AutoSmaartPass

final class PresenterTests: XCTestCase {
    func testCopyMatchesTheSpec() {
        XCTAssertEqual(PassPresenter.pickTitle, "Pick output")
        XCTAssertEqual(PassPresenter.pickSupporting, "One Matrix output. One curve. The console is not written on this step.")
        XCTAssertEqual(PassPresenter.delayTitle, "Delay")
        XCTAssertEqual(PassPresenter.delaySupporting, "Smaart delay suggestion. Not from the target or the reference.")
        XCTAssertFalse(PassPresenter.delaySupporting.contains("Suggested from"))
        XCTAssertEqual(PassPresenter.confirmWarning, "Nothing is sent until you confirm.")
        XCTAssertEqual(PassPresenter.eqSupporting(bandCount: 0), "No EQ is needed.")
        XCTAssertEqual(PassPresenter.eqSupporting(bandCount: 3), "After delay write and remeasure. 3 of 8 bands used. Unused bands stay empty.")
        XCTAssertEqual(PassPresenter.noticeText(.noSmaartTrace), "No Smaart trace.")
        XCTAssertEqual(PassPresenter.noticeText(.noDelaySuggestion), "No delay suggestion.")
        XCTAssertEqual(PassPresenter.noticeText(.noSmaartTarget), "No Smaart target curve.")
        XCTAssertEqual(PassPresenter.noticeText(.presetNoOverlap), "Preset does not overlap the trace.")
        XCTAssertEqual(PassPresenter.noticeText(.couldNotRemeasure), "Could not remeasure.")
        XCTAssertEqual(PassPresenter.noticeText(.writeFailedKept), "Write failed. Previous value kept.")
        XCTAssertEqual(PassPresenter.noticeText(.writeFailedMismatch), "Write failed. Console may not match the previous value.")
        XCTAssertEqual(PassPresenter.noticeText(.noEqNeeded), "No EQ is needed.")
        XCTAssertEqual(PassPresenter.noticeText(.noEqWritten), "No EQ was written.")
        XCTAssertNil(PassPresenter.noticeText(.none))
        XCTAssertEqual(PassPresenter.previousDelayLine(snapshot: nil), "No previous value yet")
        XCTAssertEqual(PassPresenter.eqUndoNote(hasSnapshot: false), "Previous bands are read on confirm.")
        XCTAssertEqual(PassPresenter.eqUndoNote(hasSnapshot: true), "Last undo snapshot")
        XCTAssertEqual(PassPresenter.lastWriteLabel(nil), "not written")
        XCTAssertEqual(PassPresenter.lastWriteLabel("4.0 ms · no EQ"), "4.0 ms · no EQ")
        XCTAssertEqual(PassPresenter.oscStatus(armed: true), "OSC armed")
        XCTAssertEqual(PassPresenter.oscStatus(armed: false), "OSC idle")
        XCTAssertEqual(PassPresenter.smaartLabel, "Smaart API")
        XCTAssertEqual(PassPresenter.readTrace, "Read trace")
        XCTAssertEqual(PassPresenter.storeTarget, "Store target")
        XCTAssertEqual(PassPresenter.storeTrace, "Store trace")
        XCTAssertEqual(PassPresenter.recall, "Recall")
        XCTAssertEqual(PassPresenter.confirmDelay, "Confirm delay write")
        XCTAssertEqual(PassPresenter.confirmEq, "Confirm EQ write")
        XCTAssertEqual(PassPresenter.back, "Back")
        XCTAssertEqual(PassPresenter.undoDelay, "Undo delay")
        XCTAssertEqual(PassPresenter.undoLastWrite, "Undo last write")
        XCTAssertEqual(PassPresenter.retryRemeasure, "Retry remeasure")
        XCTAssertEqual(PassPresenter.frequencyCell(nil), "—")
        XCTAssertEqual(PassPresenter.gainCell(nil), "—")
        XCTAssertEqual(PassPresenter.qCell(nil), "—")
        let band = EqBand(index: 1, hz: 3150, gainDb: -1.5, q: 4)
        XCTAssertEqual(PassPresenter.frequencyCell(band), "3.15 kHz")
        XCTAssertEqual(PassPresenter.gainCell(band), "−1.5 dB")
        XCTAssertEqual(PassPresenter.qCell(band), "4.00")
        XCTAssertEqual(PassPresenter.suggestedDelay(12.4), "12.4 ms")
        XCTAssertNotEqual(PassPresenter.suggestedDelay(12.4), "18.6 ms")
    }

    func testOscArmedOnlyWhenThatConfirmCanSend() {
        var state = PassState()
        state.host = "10.0.0.8"
        state.port = "8000"
        state.step = .pick
        XCTAssertFalse(PassPresenter.oscArmed(state))
        state.step = .delay
        state.displayedDelayMs = 12.4
        XCTAssertTrue(PassPresenter.oscArmed(state))
        state.step = .eq
        state.bands = []
        XCTAssertFalse(PassPresenter.oscArmed(state))
        state.bands = [EqBand(index: 1, hz: 100, gainDb: -6, q: 4)]
        XCTAssertTrue(PassPresenter.oscArmed(state))
        state.step = .compare
        XCTAssertFalse(PassPresenter.oscArmed(state))
        state.step = .delay
        state.host = ""
        XCTAssertFalse(PassPresenter.oscArmed(state))
    }

    func testReadAndStoreEnablement() {
        var state = PassState()
        XCTAssertFalse(PassPresenter.readEnabled(state))
        XCTAssertFalse(PassPresenter.storeEnabled(state))
        state.host = "10.0.0.8"
        state.port = "8000"
        state.selectedOutput = 1
        state.passPresetName = "Main"
        state.draftName = "Main"
        XCTAssertTrue(PassPresenter.readEnabled(state))
        XCTAssertTrue(PassPresenter.storeEnabled(state))
        state.draftName = " "
        XCTAssertFalse(PassPresenter.storeEnabled(state))
        state.step = .eq
        state.bands = []
        XCTAssertTrue(PassPresenter.confirmEqEnabled(state))
        state.bands = nil
        XCTAssertFalse(PassPresenter.confirmEqEnabled(state))
    }

    func testCompareReadout() {
        var state = PassState()
        state.selectedOutput = 1
        state.outputs = [MatrixOutputRecord(index: 1, displayName: "", lastWrite: nil, delaySnapshot: DelaySnapshot(delay: .float32(0), fineDelay: .float32(0)), eqSnapshot: nil)]
        state.displayedDelayMs = 4
        state.bands = []
        state.notice = .noEqWritten
        XCTAssertEqual(PassPresenter.compareLines(state), [
            "Delay 0.0 ms → 4.0 ms",
            "Bands written: 0. Bands left empty: 8.",
            "No EQ was written."
        ])
        state.eqRemeasureFailed = true
        state.bands = [EqBand(index: 1, hz: 100, gainDb: -6, q: 4)]
        XCTAssertTrue(PassPresenter.compareLines(state).contains("Could not remeasure."))
        XCTAssertTrue(PassPresenter.compareLines(state).contains("Bands written: 1. Bands left empty: 7."))
    }

    func testUndoControlsFollowTheSnapshot() {
        var state = PassState()
        state.selectedOutput = 1
        state.outputs = [MatrixOutputRecord(index: 1, displayName: "", lastWrite: nil, delaySnapshot: nil, eqSnapshot: nil)]
        XCTAssertFalse(PassPresenter.showsUndoDelay(state))
        XCTAssertFalse(PassPresenter.showsUndoLastWrite(state))
        state.outputs[0].delaySnapshot = DelaySnapshot(delay: .float32(1), fineDelay: .float32(1))
        XCTAssertTrue(PassPresenter.showsUndoDelay(state))
        state.step = .compare
        state.compareOpen = true
        XCTAssertTrue(PassPresenter.showsUndoLastWrite(state))
    }
}
