import Foundation
import Combine
import AutoSmaartCore
import ConsoleOSC
import SmaartAPI

public enum RingOutPhase: Equatable {
    case setup
    case running
    case notch
    case done
}

public enum RingOutNotice: Equatable {
    case none
    case noRTA
    case stopMuted
    case stopMuteIncomplete
    case notchWriteFailedRestored
    case notchWriteFailedMismatch
    case faderWriteFailed
    case eightBands
    case notchFloor
    case completePlus5
    case hostOrPortEmpty
}

public struct RingOutState: Equatable {
    public var phase: RingOutPhase = .setup
    public var host: String = ""
    public var port: String = ""
    public var faderKind: StripKind = .inputChannel
    public var faderIndex: Int = 1
    public var eqKind: StripKind = .inputChannel
    public var eqIndex: Int = 1
    public var currentFader: FaderLevel?
    public var startFader: FaderLevel?
    public var firstFeedbackFader: FaderLevel?
    public var stopFader: FaderLevel?
    public var bands: [EqBand] = []
    public var notice: RingOutNotice = .none
    public var rtaLive: Bool = false
    public var latestRTA: [MagnitudePoint] = []
    public var loopLocked: Bool = false
    public var undoAvailable: Bool = false
    public var successfulNotchWrites: Int = 0
}

public final class RingOutController: ObservableObject {
    private let smaart: SmaartReader
    private let linkFactory: (String, UInt16) throws -> OscLink
    private var link: OscLink?
    private var fader: FaderDriver?
    private var notches: NotchWriter?
    private var detector = SustainedPeakDetector()
    private var lastRaise: Date?
    private var rtaMissingSince: Date?
    private var active = false
    @Published public private(set) var state = RingOutState()

    public init(smaart: SmaartReader, linkFactory: @escaping (String, UInt16) throws -> OscLink) {
        self.smaart = smaart
        self.linkFactory = linkFactory
    }

    public func updateHost(_ host: String) {
        guard !state.loopLocked else { return }
        state.host = host
    }

    public func updatePort(_ port: String) {
        guard !state.loopLocked else { return }
        state.port = port
    }

    public func selectFader(kind: StripKind, index: Int) {
        guard !state.loopLocked else { return }
        guard stripIndexRange(kind).contains(index) else { return }
        state.faderKind = kind
        state.faderIndex = index
    }

    public func selectEQ(kind: StripKind, index: Int) {
        guard !state.loopLocked else { return }
        guard stripIndexRange(kind).contains(index) else { return }
        state.eqKind = kind
        state.eqIndex = index
    }

    public func start() {
        guard !active else { return }
        state.notice = .none
        if state.host.isEmpty || state.port.isEmpty {
            state.notice = .hostOrPortEmpty
            return
        }
        guard let port = UInt16(state.port) else {
            state.notice = .hostOrPortEmpty
            return
        }
        do {
            guard try smaart.hasActiveRTA() else {
                state.notice = .noRTA
                return
            }
            let link = try linkFactory(state.host, port)
            self.link = link
            let fader = FaderDriver(kind: state.faderKind, index: state.faderIndex, link: link)
            let notches = NotchWriter(kind: state.eqKind, index: state.eqIndex, link: link)
            let startLevel = try fader.read()
            try notches.captureUndoBaseline(readingBands: Array(1...8))
            self.fader = fader
            self.notches = notches
            detector.reset()
            lastRaise = nil
            rtaMissingSince = nil
            state.startFader = startLevel
            state.currentFader = startLevel
            state.firstFeedbackFader = nil
            state.stopFader = nil
            state.bands = []
            state.successfulNotchWrites = 0
            state.undoAvailable = false
            state.phase = .running
            state.loopLocked = true
            state.rtaLive = true
            active = true
            publishBands()
        } catch {
            state.notice = .noRTA
            active = false
            state.loopLocked = false
            state.phase = .setup
        }
    }

    public func tick(now: Date) {
        guard active else {
            refreshTrace()
            return
        }
        guard state.phase == .running else { return }
        guard let fader, let notches, link != nil else { return }

        let rta: [MagnitudePoint]
        do {
            rta = try smaart.readRTA()
            state.latestRTA = rta
            state.rtaLive = true
            rtaMissingSince = nil
        } catch {
            state.rtaLive = false
            state.latestRTA = []
            if rtaMissingSince == nil { rtaMissingSince = now }
            if let missing = rtaMissingSince, now.timeIntervalSince(missing) >= 2.0 {
                finishIdle(notice: .noRTA)
            }
            return
        }

        // Detect before raise so first-feedback captures the level that produced the peak.
        // Hold the fader while a peak streak is forming (do not climb mid-detection).
        if let peak = detector.push(rta) {
            handlePeak(peakHz: peak.hz, fader: fader, notches: notches)
            publishBands()
            return
        }
        if peakFrame(in: rta) != nil {
            publishBands()
            return
        }

        guard state.phase == .running else {
            publishBands()
            return
        }

        if lastRaise == nil || now.timeIntervalSince(lastRaise!) >= 0.2 {
            do {
                let level = try fader.raiseByHalfDb()
                state.currentFader = level
                lastRaise = now
                if let first = state.firstFeedbackFader {
                    let stopDb = faderDbComparable(first) + 5.0
                    if faderDbComparable(level) >= stopDb {
                        state.stopFader = .decibels(stopDb)
                        state.phase = .done
                        state.notice = .completePlus5
                        active = false
                        state.loopLocked = false
                        state.undoAvailable = state.successfulNotchWrites > 0
                        publishBands()
                        return
                    }
                }
            } catch {
                state.notice = .faderWriteFailed
                finishIdle(notice: .faderWriteFailed)
                return
            }
        }
        publishBands()
    }

    private func handlePeak(peakHz: Double, fader: FaderDriver, notches: NotchWriter) {
        state.phase = .notch
        if state.firstFeedbackFader == nil {
            let f0 = state.currentFader ?? .minusInfinity
            state.firstFeedbackFader = f0
            state.stopFader = .decibels(faderDbComparable(f0) + 5.0)
        }
        do {
            try fader.writeMinusInfinity()
            state.currentFader = .minusInfinity
        } catch {
            finishIdle(notice: .faderWriteFailed)
            return
        }
        do {
            let decision = try notches.apply(peakHz: peakHz)
            switch decision {
            case .write, .deepen:
                state.successfulNotchWrites += 1
                state.phase = .running
                detector.reset()
                lastRaise = nil
            case .bandCap:
                state.phase = .done
                state.notice = .eightBands
                active = false
                state.loopLocked = false
                state.undoAvailable = state.successfulNotchWrites > 0
            case .floorReached:
                state.phase = .done
                state.notice = .notchFloor
                active = false
                state.loopLocked = false
                state.undoAvailable = state.successfulNotchWrites > 0
            }
            publishBands()
        } catch let error as ConfirmError {
            state.currentFader = .minusInfinity
            switch error {
            case .kept: finishIdle(notice: .notchWriteFailedRestored)
            case .mismatch: finishIdle(notice: .notchWriteFailedMismatch)
            }
        } catch {
            finishIdle(notice: .notchWriteFailedRestored)
        }
    }

    public func stop() {
        active = false
        state.loopLocked = false
        state.phase = .setup
        if let link {
            let result = muteAll(link: link)
            state.notice = result.accepted == result.attempted ? .stopMuted : .stopMuteIncomplete
        } else {
            state.notice = .stopMuted
        }
        state.undoAvailable = state.successfulNotchWrites > 0
        publishBands()
    }

    public func undoNotches() {
        guard !active else { return }
        guard state.undoAvailable, let notches else { return }
        do {
            try notches.undo()
            state.bands = []
            state.successfulNotchWrites = 0
            state.undoAvailable = false
            state.notice = .none
        } catch {
            state.notice = .notchWriteFailedMismatch
        }
    }

    private func finishIdle(notice: RingOutNotice) {
        active = false
        state.loopLocked = false
        state.phase = .setup
        state.notice = notice
        state.undoAvailable = state.successfulNotchWrites > 0
        publishBands()
    }

    private func refreshTrace() {
        do {
            guard try smaart.hasActiveRTA() else {
                state.rtaLive = false
                state.latestRTA = []
                return
            }
            state.latestRTA = try smaart.readRTA()
            state.rtaLive = true
        } catch {
            state.rtaLive = false
            state.latestRTA = []
        }
    }

    private func publishBands() {
        state.bands = notches?.bands ?? state.bands
    }
}
