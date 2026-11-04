import Foundation
import Combine
import AutoSmaartCore
import ConsoleOSC
import SmaartAPI

public enum PassStep: Equatable { case pick, delay, eq, compare }

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
}

public struct PassState: Equatable {
    public var step: PassStep = .pick
    public var host = ""
    public var port = ""
    public var draftName = ""
    public var selectedOutput: Int?
    public var passPresetName: String?
    public var outputs: [MatrixOutputRecord] = []
    public var presets: [CurvePreset] = []
    public var latestMagnitude: [MagnitudePoint]?
    public var suggestionRaw: Double?
    public var displayedDelayMs: Double?
    public var postDelayMagnitude: [MagnitudePoint]?
    public var bands: [EqBand]?
    public var beforeCurve: [MagnitudePoint]?
    public var afterCurve: [MagnitudePoint]?
    public var notice: PassNotice = .none
    public var smaartLive = false
    public var delayWrittenThisPass = false
    public var compareOpen = false
    public var eqRemeasureFailed = false

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

    public init(reader: SmaartReader, link: OscLink, bank: CurveBank, outputs: OutputStore) {
        self.reader = reader
        self.link = link
        self.bank = bank
        self.outputs = outputs
        var initial = PassState()
        initial.presets = bank.presets
        initial.outputs = outputs.outputs
        initial.smaartLive = reader.isSessionOpen
        state = initial
    }

    public func setHost(_ host: String) { state.host = host; endpoint?.update(host: state.host, port: state.port) }
    public func setPort(_ port: String) { state.port = port; endpoint?.update(host: state.host, port: state.port) }
    public func setDraftName(_ name: String) { state.draftName = name }

    public func refreshSessionFlag() { state.smaartLive = reader.isSessionOpen }

    func reloadFromStores() {
        try? bank.reload()
        state.presets = bank.presets
        state.outputs = outputs.outputs
    }

    func storePreparedPreset(name: String, kind: CurveKind, points: [MagnitudePoint]) throws {
        try bank.store(name: name, kind: kind, points: points)
        state.presets = bank.presets
    }

    public func selectOutput(_ index: Int) {
        guard (1...12).contains(index) else { return }
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
            state.presets = bank.presets
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
            state.presets = bank.presets
            state.notice = .none
        } catch {
            return
        }
    }

    public func readTrace() {
        guard state.selectedOutput != nil, state.passPresetName != nil, !state.host.isEmpty, !state.port.isEmpty else { return }
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
    }

    public func back() {
        if state.step == .delay { state.step = .pick }
    }

    public func canOpen(_ step: PassStep) -> Bool {
        switch step {
        case .pick: return true
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
    }

    private func clearPassProgress() {
        state.suggestionRaw = nil
        state.displayedDelayMs = nil
        state.latestMagnitude = nil
        state.postDelayMagnitude = nil
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

