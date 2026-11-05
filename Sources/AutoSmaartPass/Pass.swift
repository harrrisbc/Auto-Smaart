import Foundation
import Combine
import AutoSmaartCore
import ConsoleOSC
import SmaartAPI

public enum PassStep: Equatable { case pick, settings, delay, eq, compare }

public enum PassNotice: Equatable {
    case none
    case noSmaartTrace
    case noDelaySuggestion
    case noSmaartTarget
    case presetNoOverlap
    case couldNotRemeasure
    case writeFailedKept
    case writeFailedMismatch
    case noEqNeeded
    case noEqWritten
    case matrixMuteIncomplete
    case matrixMixIncomplete
}

public struct PassState: Equatable {
    public var step: PassStep = .pick
    public var host = ""
    public var port = ""
    public var draftName = ""
    /// Optional Smaart TF measurement name (e.g. "hi"). Blank → first active TF.
    public var transferFunctionName = ""
    public var selectedOutput: Int?
    public var passPresetName: String?
    public var outputs: [MatrixOutputRecord] = []
    public var presets: [CurvePreset] = []
    public var latestMagnitude: [MagnitudePoint]?
    public var suggestionRaw: Double?
    public var displayedDelayMs: Double?
    public var postDelayMagnitude: [MagnitudePoint]?
    /// Display fit from the last Read and the selected preset. Not the write path.
    public var previewBands: [EqBand]?
    public var bands: [EqBand]?
    public var beforeCurve: [MagnitudePoint]?
    public var afterCurve: [MagnitudePoint]?
    public var notice: PassNotice = .none
    public var smaartLive = false
    public var delayWrittenThisPass = false
    public var compareOpen = false
    public var eqRemeasureFailed = false
    /// Per Matrix output index: how many successful Reads have captured a Smaart TF.
    public var readCounts: [Int: Int] = [:]

    public init() {}
}

public protocol ConsoleEndpoint: AnyObject {
    func update(host: String, port: String)
}

public final class PassController: ObservableObject {
    @Published public fileprivate(set) var state: PassState
    fileprivate let reader: SmaartReader
    fileprivate let link: OscLink
    private let bank: CurveBank
    fileprivate let outputs: OutputStore
    public weak var endpoint: ConsoleEndpoint?
    @Published public var matrixPickerOpen = false
    @Published public var presetPickerOpen = false
    @Published public var settingsOpen = false

    public init(reader: SmaartReader, link: OscLink, bank: CurveBank, outputs: OutputStore) {
        self.reader = reader
        self.link = link
        self.bank = bank
        self.outputs = outputs
        var initial = PassState()
        initial.presets = BuiltInTargets.merge(bank: bank.presets)
        initial.outputs = outputs.outputs
        initial.smaartLive = reader.isSessionOpen
        state = initial
    }

    public func setHost(_ host: String) { state.host = host; endpoint?.update(host: state.host, port: state.port) }
    public func setPort(_ port: String) { state.port = port; endpoint?.update(host: state.host, port: state.port) }
    public func setDraftName(_ name: String) { state.draftName = name }
    public func setTransferFunctionName(_ name: String) {
        state.transferFunctionName = name
        reader.preferredMeasurementName = name
    }

    public func refreshSessionFlag() { state.smaartLive = reader.isSessionOpen }

    func reloadFromStores() {
        try? bank.reload()
        state.presets = BuiltInTargets.merge(bank: bank.presets)
        state.outputs = outputs.outputs
    }

    func storePreparedPreset(name: String, kind: CurveKind, points: [MagnitudePoint]) throws {
        try bank.store(name: name, kind: kind, points: points)
        state.presets = BuiltInTargets.merge(bank: bank.presets)
    }

    private func syncPresetList() {
        state.presets = BuiltInTargets.merge(bank: bank.presets)
    }

    public func selectOutput(_ index: Int) {
        guard (1...12).contains(index) else { return }
        state.smaartLive = reader.isSessionOpen
        if state.selectedOutput == index { return }
        state.selectedOutput = index
        clearPassProgress()
    }

    public func setDisplayName(_ name: String, output: Int) {
        guard (1...12).contains(output) else { return }
        state.outputs[output - 1].displayName = name
        try? outputs.save(state.outputs)
    }

    public func recall(name: String) {
        guard state.presets.contains(where: { $0.name == name }) else { return }
        if state.passPresetName == name { return }
        state.passPresetName = name
        clearPassProgress()
    }

    public func storeTarget() {
        do {
            let points = try reader.readTargetCurve()
            try bank.store(name: state.draftName, kind: .target, points: points)
            syncPresetList()
            state.notice = .none
        } catch is CurveBankError {
            return
        } catch {
            state.notice = .noSmaartTarget
        }
    }

    public func storeTrace() {
        guard let latest = state.latestMagnitude, !latest.isEmpty else {
            state.notice = .noSmaartTrace
            return
        }
        do {
            try bank.store(name: state.draftName, kind: .reference, points: latest)
            syncPresetList()
            state.notice = .none
        } catch {
            return
        }
    }

    /// Turns the Smaart signal generator output off. Leaves the TF measurement running.
    public func stop() {
        if !reader.isSessionOpen {
            try? reader.openSession()
            refreshSessionFlag()
        }
        guard reader.isSessionOpen else { return }
        try? reader.setSignalGeneratorActive(false)
    }

    /// Turns the Smaart signal generator output back on so the pass can continue.
    public func startGenerator() {
        if !reader.isSessionOpen {
            try? reader.openSession()
            refreshSessionFlag()
        }
        guard reader.isSessionOpen else { return }
        try? reader.setSignalGeneratorActive(true)
    }

    /// Mutes only the Matrix output selected on this page.
    public func muteSelectedMatrix() {
        writeSelectedMatrixMute(active: true)
    }

    /// Unmutes only the Matrix output selected on this page (Mix).
    public func mixSelectedMatrix() {
        writeSelectedMatrixMute(active: false)
    }

    private func writeSelectedMatrixMute(active: Bool) {
        guard let output = state.selectedOutput else { return }
        do {
            let address = try muteAddress(kind: .matrixBus, index: output)
            try link.write(address: address, value: .int32(active ? 1 : 0))
            if state.notice == .matrixMuteIncomplete || state.notice == .matrixMixIncomplete {
                state.notice = .none
            }
        } catch {
            state.notice = active ? .matrixMuteIncomplete : .matrixMixIncomplete
        }
    }

    public func readTrace() {
        if !reader.isSessionOpen {
            try? reader.openSession()
            refreshSessionFlag()
        }
        reader.preferredMeasurementName = state.transferFunctionName
        guard state.selectedOutput != nil, reader.isSessionOpen else { return }
        let capture: SmaartCapture
        do {
            capture = try reader.readTrace()
        } catch {
            refuseTrace()
            return
        }
        if capture.magnitude.isEmpty {
            refuseTrace()
            return
        }
        state.latestMagnitude = capture.magnitude
        if let output = state.selectedOutput {
            let count = (state.readCounts[output] ?? 0) + 1
            state.readCounts[output] = count
            let display = state.outputs.first(where: { $0.index == output })?.displayName ?? ""
            let name = PassPresenter.capturedTraceName(
                output: output,
                displayName: display,
                readNumber: count
            )
            try? reader.captureTransferFunction(as: name)
        }
        switch delaySuggestion(of: capture) {
        case .none:
            state.suggestionRaw = nil
            state.displayedDelayMs = nil
            state.bands = nil
            state.compareOpen = false
            state.notice = .noDelaySuggestion
            state.step = .pick
        case .milliseconds(let raw):
            state.suggestionRaw = raw
            state.displayedDelayMs = displayedDelayMs(raw)
            state.bands = nil
            state.postDelayMagnitude = nil
            state.beforeCurve = nil
            state.afterCurve = nil
            state.compareOpen = false
            state.delayWrittenThisPass = false
            state.eqRemeasureFailed = false
            state.notice = .none
            state.step = .delay
        }
        updatePreview(from: capture.magnitude)
    }

    public func back() {
        if state.step == .delay || state.step == .settings { state.step = .pick }
    }

    public func canOpen(_ step: PassStep) -> Bool {
        switch step {
        case .pick, .settings: return true
        case .delay: return state.suggestionRaw != nil
        case .eq: return state.bands != nil
        case .compare: return state.compareOpen
        }
    }

    public func openRail(_ step: PassStep) {
        guard canOpen(step) else { return }
        state.step = step
    }

    private func refuseTrace() {
        state.notice = .noSmaartTrace
        state.step = .pick
        state.suggestionRaw = nil
        state.displayedDelayMs = nil
        state.previewBands = nil
    }

    /// Bands for the graph only. `bands` stays empty until delay confirm and remeasure.
    private func updatePreview(from magnitude: [MagnitudePoint]) {
        guard let name = state.passPresetName,
              let preset = state.presets.first(where: { $0.name == name }) else {
            state.previewBands = nil
            return
        }
        switch fitEq(measurement: magnitude, preset: preset.points) {
        case .noOverlap:
            state.previewBands = nil
        case .bands(let bands):
            state.previewBands = bands
        }
    }

    private func clearPassProgress() {
        state.suggestionRaw = nil
        state.displayedDelayMs = nil
        state.latestMagnitude = nil
        state.postDelayMagnitude = nil
        state.previewBands = nil
        state.bands = nil
        state.beforeCurve = nil
        state.afterCurve = nil
        state.notice = .none
        state.delayWrittenThisPass = false
        state.compareOpen = false
        state.eqRemeasureFailed = false
        state.step = .pick
    }
}

extension PassController {
    public func confirmDelay() {
        guard state.step == .delay, let shown = state.displayedDelayMs, let output = state.selectedOutput else { return }
        guard !state.host.isEmpty, UInt16(state.port) != nil else {
            state.notice = .writeFailedKept
            return
        }
        let addresses: (delay: String, fineDelay: String)
        do { addresses = try delayAddresses(output: output) } catch { return }
        let value = OscValue.float32(Float(shown))
        do {
            let restore = try confirmReplace([
                Replacement(address: addresses.delay, value: value),
                Replacement(address: addresses.fineDelay, value: value)
            ], link: link)
            state.outputs[output - 1].delaySnapshot = DelaySnapshot(delay: restore[0].value, fineDelay: restore[1].value)
            try? outputs.save(state.outputs)
            state.delayWrittenThisPass = true
            state.notice = .none
            remeasureAfterDelay()
        } catch let error as ConfirmError {
            state.notice = error == .mismatch ? .writeFailedMismatch : .writeFailedKept
        } catch {
            state.notice = .writeFailedKept
        }
    }

    public func retryRemeasure() {
        guard state.step == .delay, state.delayWrittenThisPass, state.notice == .couldNotRemeasure else { return }
        remeasureAfterDelay()
    }

    fileprivate func remeasureAfterDelay() {
        let capture: SmaartCapture
        do { capture = try reader.readTrace() } catch {
            state.notice = .couldNotRemeasure
            state.step = .delay
            state.bands = nil
            return
        }
        if capture.magnitude.isEmpty {
            state.notice = .couldNotRemeasure
            state.step = .delay
            state.bands = nil
            return
        }
        guard let name = state.passPresetName, let preset = state.presets.first(where: { $0.name == name }) else {
            state.notice = .couldNotRemeasure
            state.step = .delay
            return
        }
        switch fitEq(measurement: capture.magnitude, preset: preset.points) {
        case .noOverlap:
            state.postDelayMagnitude = capture.magnitude
            state.notice = .presetNoOverlap
            state.step = .delay
            state.bands = nil
        case .bands(let bands):
            state.postDelayMagnitude = capture.magnitude
            state.bands = bands
            state.step = .eq
            state.notice = bands.isEmpty ? .noEqNeeded : .none
        }
    }
}

extension PassController {
    func setSeededEQSnapshot(_ snapshot: [EqBandSnapshot]) {
        guard let output = state.selectedOutput else { return }
        state.outputs[output - 1].eqSnapshot = snapshot
        try? outputs.save(state.outputs)
    }

    public func confirmEq() {
        guard state.step == .eq, let bands = state.bands, let output = state.selectedOutput else { return }
        // Console writes stay peaking/bell. Suggested low shelves are drawn only.
        let writeBands = bands.filter { $0.shape == .peaking }
        if writeBands.isEmpty {
            state.beforeCurve = state.postDelayMagnitude
            state.afterCurve = state.postDelayMagnitude
            state.eqRemeasureFailed = false
            state.notice = .noEqWritten
            openCompare(output: output)
            return
        }
        guard !state.host.isEmpty, UInt16(state.port) != nil else {
            state.notice = .writeFailedKept
            return
        }
        var items: [Replacement] = []
        for band in writeBands {
            let addresses: (freq: String, gain: String, q: String, on: String)
            do { addresses = try eqAddresses(output: output, band: band.index) } catch { return }
            items.append(Replacement(address: addresses.freq, value: .float32(Float(band.hz))))
            items.append(Replacement(address: addresses.gain, value: .float32(Float(band.gainDb))))
            items.append(Replacement(address: addresses.q, value: .float32(Float(band.q))))
            items.append(Replacement(address: addresses.on, value: .int32(1)))
        }
        do {
            let restore = try confirmReplace(items, link: link)
            var snapshots: [EqBandSnapshot] = []
            for (offset, band) in writeBands.enumerated() {
                let base = offset * 4
                snapshots.append(EqBandSnapshot(
                    index: band.index,
                    freq: restore[base].value,
                    gain: restore[base + 1].value,
                    q: restore[base + 2].value,
                    on: restore[base + 3].value
                ))
            }
            state.outputs[output - 1].eqSnapshot = snapshots
            try? outputs.save(state.outputs)
            remeasureAfterEq(output: output)
        } catch let error as ConfirmError {
            state.notice = error == .mismatch ? .writeFailedMismatch : .writeFailedKept
        } catch {
            state.notice = .writeFailedKept
        }
    }

    fileprivate func remeasureAfterEq(output: Int) {
        state.beforeCurve = state.postDelayMagnitude
        do {
            let capture = try reader.readTrace()
            if capture.magnitude.isEmpty {
                state.afterCurve = nil
                state.eqRemeasureFailed = true
                state.notice = .couldNotRemeasure
            } else {
                state.afterCurve = capture.magnitude
                state.eqRemeasureFailed = false
                state.notice = .none
            }
        } catch {
            state.afterCurve = nil
            state.eqRemeasureFailed = true
            state.notice = .couldNotRemeasure
        }
        openCompare(output: output)
    }

    fileprivate func openCompare(output: Int) {
        if let shown = state.displayedDelayMs {
            let count = state.bands?.count ?? 0
            state.outputs[output - 1].lastWrite = count == 0
                ? String(format: "%.1f ms · no EQ", shown)
                : String(format: "%.1f ms · %d bands", shown, count)
            try? outputs.save(state.outputs)
        }
        state.compareOpen = true
        state.step = .compare
    }
}

extension PassController {
    public func undoDelay() {
        guard let output = state.selectedOutput, let snapshot = state.outputs[output - 1].delaySnapshot else { return }
        let addresses: (delay: String, fineDelay: String)
        do { addresses = try delayAddresses(output: output) } catch { return }
        sendUndo([
            Replacement(address: addresses.delay, value: snapshot.delay),
            Replacement(address: addresses.fineDelay, value: snapshot.fineDelay)
        ])
    }

    public func undoLastWrite() {
        guard let output = state.selectedOutput else { return }
        let lastWrite = state.outputs[output - 1].lastWrite
        var items: [Replacement] = []
        if let snapshot = state.outputs[output - 1].delaySnapshot, let addresses = try? delayAddresses(output: output) {
            items.append(Replacement(address: addresses.delay, value: snapshot.delay))
            items.append(Replacement(address: addresses.fineDelay, value: snapshot.fineDelay))
        }
        for band in (state.outputs[output - 1].eqSnapshot ?? []).sorted(by: { $0.index < $1.index }) {
            guard let addresses = try? eqAddresses(output: output, band: band.index) else { continue }
            items.append(Replacement(address: addresses.freq, value: band.freq))
            items.append(Replacement(address: addresses.gain, value: band.gain))
            items.append(Replacement(address: addresses.q, value: band.q))
            items.append(Replacement(address: addresses.on, value: band.on))
        }
        sendUndo(items)
        state.outputs[output - 1].lastWrite = lastWrite
    }

    fileprivate func sendUndo(_ items: [Replacement]) {
        let snapshots = state.outputs
        do {
            try writeOnly(items, link: link)
            state.notice = .none
        } catch let error as ConfirmError {
            state.outputs = snapshots
            state.notice = error == .mismatch ? .writeFailedMismatch : .writeFailedKept
        } catch {
            state.outputs = snapshots
            state.notice = .writeFailedKept
        }
    }
}



