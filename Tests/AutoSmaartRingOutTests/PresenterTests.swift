import XCTest
import AutoSmaartCore
@testable import AutoSmaartRingOut

final class PresenterTests: XCTestCase {
    func testErrorCopyMatchesSpec() {
        XCTAssertEqual(RingOutPresenter.noticeText(.noRTA), "No RTA")
        XCTAssertEqual(RingOutPresenter.noticeText(.stopMuteIncomplete), "Stop: channel mute failed. Check the console.")
        XCTAssertEqual(RingOutPresenter.noticeText(.stopMuted), "Selected channel muted. Loop idle.")
        XCTAssertEqual(RingOutPresenter.noticeText(.notchWriteFailedRestored), "Notch write failed. Previous EQ restored.")
        XCTAssertEqual(RingOutPresenter.noticeText(.notchWriteFailedMismatch), "Notch write failed. Console EQ may not match the previous value.")
        XCTAssertEqual(RingOutPresenter.noticeText(.faderWriteFailed), "Fader write failed.")
        XCTAssertEqual(RingOutPresenter.noticeText(.eightBands), "8 bands used before +5 dB headroom.")
        XCTAssertEqual(RingOutPresenter.noticeText(.notchFloor), "Notch floor reached.")
        XCTAssertEqual(RingOutPresenter.noticeText(.completePlus5), "Ring-out complete (+5 dB).")
        XCTAssertEqual(RingOutPresenter.stopAction, "Stop")
        XCTAssertEqual(RingOutPresenter.startAction, "Start ring-out")
        XCTAssertEqual(RingOutPresenter.undoAction, "Undo notches")
        XCTAssertEqual(RingOutPresenter.smaartLive, "Smaart live")
        XCTAssertEqual(RingOutPresenter.leaveAction, "Calibration")
        XCTAssertEqual(RingOutPresenter.modeLockNote, "Mode switch locked while loop runs. Stop first.")
        XCTAssertEqual(RingOutPresenter.statusText(rtaLive: true, notice: .none, host: "127.0.0.1", port: "9000"), "Smaart live")
        XCTAssertEqual(RingOutPresenter.statusText(rtaLive: false, notice: .none, host: "127.0.0.1", port: "9000"), "No RTA")
        XCTAssertEqual(RingOutPresenter.statusText(rtaLive: true, notice: .none, host: "", port: ""), "Enter the console host and OSC port.")
        XCTAssertEqual(RingOutPresenter.statusText(rtaLive: true, notice: .completePlus5, host: "127.0.0.1", port: "9000"), "Ring-out complete (+5 dB).")
        XCTAssertEqual(RingOutPresenter.targetLabel(faderKind: .inputChannel, faderIndex: 12, eqKind: .inputChannel, eqIndex: 12), "Ch 12")
        XCTAssertEqual(RingOutPresenter.targetLabel(faderKind: .inputChannel, faderIndex: 12, eqKind: .matrixBus, eqIndex: 3), "Ch 12 · EQ Matrix 3")
    }

    func testBandCellsAndFader() {
        XCTAssertEqual(RingOutPresenter.frequencyCell(nil), "—")
        XCTAssertEqual(RingOutPresenter.frequencyCell(EqBand(index: 1, hz: 80.4, gainDb: -3, q: 16)), "80 Hz")
        XCTAssertEqual(RingOutPresenter.frequencyCell(EqBand(index: 1, hz: 3150, gainDb: -3, q: 16)), "3.15 kHz")
        XCTAssertEqual(RingOutPresenter.gainCell(EqBand(index: 1, hz: 1000, gainDb: -3, q: 16)), "−3.0 dB")
        XCTAssertEqual(RingOutPresenter.qCell(EqBand(index: 1, hz: 1000, gainDb: -3, q: 16)), "16.00")
        XCTAssertEqual(RingOutPresenter.faderCell(.minusInfinity), "−∞")
        XCTAssertEqual(RingOutPresenter.faderCell(.decibels(-4.5)), "−4.5 dB")
    }
}
