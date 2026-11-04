import Foundation
import AutoSmaartCore

public enum PassPresenter {
    public static let pickTitle = "Pick output"
    public static let pickSupporting = "One Matrix output. One curve. The console is not written on this step."
    public static let delayTitle = "Delay"
    public static let delaySupporting = "Smaart delay suggestion. Not from the target or the reference."
    public static let eqTitle = "EQ"
    public static let compareTitle = "Compare"
    public static let confirmWarning = "Nothing is sent until you confirm."
    public static let smaartLabel = "Smaart API"
    public static let readTrace = "Read trace"
    public static let storeTarget = "Store target"
    public static let storeTrace = "Store trace"
    public static let recall = "Recall"
    public static let confirmDelay = "Confirm delay write"
    public static let confirmEq = "Confirm EQ write"
    public static let back = "Back"
    public static let undoDelay = "Undo delay"
    public static let undoLastWrite = "Undo last write"
    public static let retryRemeasure = "Retry remeasure"
    public static let emDash = "—"

    public static func eqSupporting(bandCount: Int) -> String {
        if bandCount == 0 { return "No EQ is needed." }
        return "After delay write and remeasure. \(bandCount) of 8 bands used. Unused bands stay empty."
    }

    public static func noticeText(_ notice: PassNotice) -> String? {
        switch notice {
        case .none: return nil
        case .noSmaartTrace: return "No Smaart trace."
        case .noDelaySuggestion: return "No delay suggestion."
        case .noSmaartTarget: return "No Smaart target curve."
        case .presetNoOverlap: return "Preset does not overlap the trace."
        case .couldNotRemeasure: return "Could not remeasure."
        case .writeFailedKept: return "Write failed. Previous value kept."
        case .writeFailedMismatch: return "Write failed. Console may not match the previous value."
        case .noEqNeeded: return "No EQ is needed."
        case .noEqWritten: return "No EQ was written."
        }
    }

    public static func previousDelayLine(snapshot: DelaySnapshot?) -> String {
        guard let snapshot else { return "No previous value yet" }
        return "delay \(oneDecimal(snapshot.delay)) · fine_delay \(oneDecimal(snapshot.fineDelay))"
    }

    public static func eqUndoNote(hasSnapshot: Bool) -> String {
        hasSnapshot ? "Last undo snapshot" : "Previous bands are read on confirm."
    }

    public static func lastWriteLabel(_ value: String?) -> String { value ?? "not written" }

    public static func oscStatus(armed: Bool) -> String { armed ? "OSC armed" : "OSC idle" }

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

    public static func suggestedDelay(_ displayed: Double) -> String {
        String(format: "%.1f ms", displayed)
    }

    public static func oscArmed(_ state: PassState) -> Bool {
        guard !state.host.isEmpty, !state.port.isEmpty else { return false }
        if state.step == .delay, state.displayedDelayMs != nil { return true }
        if state.step == .eq, let bands = state.bands, !bands.isEmpty { return true }
        return false
    }

    public static func readEnabled(_ state: PassState) -> Bool {
        state.selectedOutput != nil && state.passPresetName != nil && !state.host.isEmpty && !state.port.isEmpty
    }

    public static func storeEnabled(_ state: PassState) -> Bool {
        !state.draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public static func confirmEqEnabled(_ state: PassState) -> Bool {
        state.step == .eq && state.bands != nil && !state.host.isEmpty && UInt16(state.port) != nil
    }

    public static func confirmDelayEnabled(_ state: PassState) -> Bool {
        state.step == .delay && state.displayedDelayMs != nil && !state.host.isEmpty && UInt16(state.port) != nil
    }

    public static func compareLines(_ state: PassState) -> [String] {
        var lines: [String] = []
        if let output = state.selectedOutput,
           state.outputs.indices.contains(output - 1),
           let snapshot = state.outputs[output - 1].delaySnapshot,
           let shown = state.displayedDelayMs {
            lines.append("Delay \(oneDecimal(snapshot.delay)) ms → \(String(format: "%.1f", shown)) ms")
        }
        let count = state.bands?.count ?? 0
        lines.append("Bands written: \(count). Bands left empty: \(8 - count).")
        if count == 0 { lines.append("No EQ was written.") }
        if state.eqRemeasureFailed { lines.append("Could not remeasure.") }
        return lines
    }

    public static func showsUndoDelay(_ state: PassState) -> Bool {
        guard let output = state.selectedOutput, state.outputs.indices.contains(output - 1) else { return false }
        return state.outputs[output - 1].delaySnapshot != nil
    }

    public static func showsUndoLastWrite(_ state: PassState) -> Bool {
        guard state.step == .compare, let output = state.selectedOutput, state.outputs.indices.contains(output - 1) else { return false }
        let row = state.outputs[output - 1]
        return row.delaySnapshot != nil || row.eqSnapshot != nil
    }

    public static func selectionSummary(_ state: PassState) -> String {
        let output = state.selectedOutput.map { "Matrix \($0)" } ?? "No output"
        let preset = state.passPresetName ?? "No preset"
        return "\(output) · \(preset)"
    }

    public static func kindLabel(_ kind: CurveKind) -> String {
        kind == .target ? "Target" : "Reference"
    }

    private static func oneDecimal(_ value: OscValue) -> String {
        switch value {
        case .float32(let number):
            return String(format: "%.1f", roundHalfAwayFromZero(Double(number), places: 1))
        case .int32(let number):
            return String(number)
        }
    }
}
