import Foundation
import AutoSmaartCore

public enum RingOutPresenter {
    public static let smaartLive = "Smaart live"
    public static let startAction = "Start ring-out"
    public static let undoAction = "Undo notches"
    public static let stopAction = "Stop"
    public static let leaveAction = "Calibration"
    public static let faderTargetHeading = "Fader"
    public static let eqTargetHeading = "EQ write"
    public static let modeLockNote = "Mode switch locked while loop runs. Stop first."
    public static let emDash = "—"

    public static func noticeText(_ notice: RingOutNotice) -> String {
        switch notice {
        case .none: return ""
        case .noRTA: return "No RTA"
        case .stopMuted: return "Selected channel muted. Loop idle."
        case .stopMuteIncomplete: return "Stop: channel mute failed. Check the console."
        case .notchWriteFailedRestored: return "Notch write failed. Previous EQ restored."
        case .notchWriteFailedMismatch: return "Notch write failed. Console EQ may not match the previous value."
        case .faderWriteFailed: return "Fader write failed."
        case .eightBands: return "8 bands used before +5 dB headroom."
        case .notchFloor: return "Notch floor reached."
        case .completePlus5: return "Ring-out complete (+5 dB)."
        case .hostOrPortEmpty: return "Enter the console host and OSC port."
        }
    }

    public static func statusText(rtaLive: Bool, notice: RingOutNotice, host: String, port: String) -> String {
        if notice != .none { return noticeText(notice) }
        if host.isEmpty || port.isEmpty { return noticeText(.hostOrPortEmpty) }
        return rtaLive ? smaartLive : noticeText(.noRTA)
    }

    public static func kindName(_ kind: StripKind) -> String {
        switch kind {
        case .inputChannel: return "Input"
        case .groupBus: return "Group"
        case .auxBus: return "Aux"
        case .matrixBus: return "Matrix"
        }
    }

    public static func stripLabel(kind: StripKind, index: Int) -> String {
        switch kind {
        case .inputChannel: return "Ch \(index)"
        case .groupBus: return "Group \(index)"
        case .auxBus: return "Aux \(index)"
        case .matrixBus: return "Matrix \(index)"
        }
    }

    public static func targetLabel(faderKind: StripKind, faderIndex: Int, eqKind: StripKind, eqIndex: Int) -> String {
        let fader = stripLabel(kind: faderKind, index: faderIndex)
        if faderKind == eqKind && faderIndex == eqIndex { return fader }
        return "\(fader) · EQ \(stripLabel(kind: eqKind, index: eqIndex))"
    }

    public static func frequencyCell(_ band: EqBand?) -> String {
        guard let band else { return emDash }
        return formatFrequency(band.hz)
    }

    public static func gainCell(_ band: EqBand?) -> String {
        guard let band else { return emDash }
        let rounded = roundHalfAwayFromZero(band.gainDb, places: 1)
        let sign = rounded > 0 ? "+" : (rounded < 0 ? "−" : "")
        return "\(sign)\(String(format: "%.1f", abs(rounded))) dB"
    }

    public static func qCell(_ band: EqBand?) -> String {
        guard let band else { return emDash }
        return String(format: "%.2f", band.q)
    }

    public static func faderCell(_ level: FaderLevel?) -> String {
        guard let level else { return emDash }
        switch level {
        case .minusInfinity: return "−∞"
        case .decibels(let db):
            let rounded = roundHalfAwayFromZero(db, places: 1)
            let sign = rounded > 0 ? "+" : (rounded < 0 ? "−" : "")
            return "\(sign)\(String(format: "%.1f", abs(rounded))) dB"
        }
    }

}
