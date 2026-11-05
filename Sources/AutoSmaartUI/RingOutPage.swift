import SwiftUI
import Combine
import AutoSmaartRingOut
import AutoSmaartCore
import AutoSmaartPass

public struct RingOutPage: View {
    @ObservedObject var controller: RingOutController
    /// Shared calibration pass — Settings host/port live here; Back syncs into Ring Out.
    var calibration: PassController?
    let onLeave: () -> Void
    @State private var settingsOpen = false
    @State private var faderIndexDraft = ""
    @State private var eqIndexDraft = ""

    public init(
        controller: RingOutController,
        calibration: PassController? = nil,
        onLeave: @escaping () -> Void
    ) {
        self.controller = controller
        self.calibration = calibration
        self.onLeave = onLeave
    }

    public var body: some View {
        HStack(spacing: 0) {
            fullHeightFader
                .frame(width: 160)
                .frame(maxHeight: .infinity)

            VStack(spacing: 0) {
                topBar
                stripPanel
                    .frame(maxWidth: .infinity)
                    .layoutPriority(1)
                RTAPlot(points: controller.state.latestRTA, bands: controller.state.bands)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, ThemeMetrics.pagePadding)
                    .padding(.bottom, ThemeMetrics.pagePadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.background)
        .foregroundStyle(Theme.text)
        .overlay { settingsOverlay }
        .onAppear { syncIndexDrafts() }
        .onChange(of: controller.state.faderKind) { _, _ in
            faderIndexDraft = String(controller.state.faderIndex)
        }
        .onChange(of: controller.state.eqKind) { _, _ in
            eqIndexDraft = String(controller.state.eqIndex)
        }
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { date in
            controller.tick(now: date)
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Text(RingOutPresenter.statusText(
                rtaLive: controller.state.rtaLive,
                notice: controller.state.notice,
                host: controller.state.host,
                port: controller.state.port
            ))
            .font(.custom("Inter", size: 13))
            .foregroundStyle(Theme.secondary)
            Spacer()
            QuietButton(title: PassPresenter.settings) {
                guard !controller.state.loopLocked else { return }
                settingsOpen = true
            }
            .disabled(controller.state.loopLocked || calibration == nil)
            QuietButton(title: RingOutPresenter.leaveAction) {
                guard !controller.state.loopLocked else { return }
                onLeave()
            }
            .disabled(controller.state.loopLocked)
            QuietButton(title: RingOutPresenter.stopAction) { controller.stop() }
        }
        .padding(.horizontal, ThemeMetrics.pagePadding)
        .frame(height: ThemeMetrics.titleBar)
    }

    @ViewBuilder
    private var settingsOverlay: some View {
        if settingsOpen, let calibration {
            ZStack {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture { closeSettings(calibration) }
                VStack(alignment: .leading, spacing: 0) {
                    SettingsView(controller: calibration)
                    QuietButton(title: PassPresenter.back) { closeSettings(calibration) }
                        .padding(.horizontal, ThemeMetrics.pagePadding)
                        .padding(.bottom, ThemeMetrics.pagePadding)
                }
                .frame(width: 440, height: 560)
                .background(Theme.background)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.stroke))
            }
        }
    }

    private func closeSettings(_ calibration: PassController) {
        settingsOpen = false
        controller.updateHost(calibration.state.host)
        controller.updatePort(calibration.state.port)
    }

    private var fullHeightFader: some View {
        VStack(spacing: 16) {
            Text(RingOutPresenter.faderCell(controller.state.currentFader))
                .font(.custom("Inter", size: 28).weight(.semibold))
                .monospacedDigit()
                .padding(.top, ThemeMetrics.pagePadding)
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 6).fill(Theme.raised)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.live)
                        .frame(height: max(4, geo.size.height * faderFraction(controller.state.currentFader)))
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, ThemeMetrics.pagePadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.raised)
        .overlay(Rectangle().stroke(Theme.stroke, lineWidth: 1))
    }

    private var stripPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(RingOutPresenter.faderTargetHeading)
                .font(.custom("Inter", size: 13).weight(.semibold))
                .foregroundStyle(Theme.lightGold)
            kindRow(
                selected: controller.state.faderKind,
                set: { controller.selectFader(kind: $0, index: clampedIndex($0, controller.state.faderIndex)) }
            )
            indexField(
                kind: controller.state.faderKind,
                draft: $faderIndexDraft,
                commit: { controller.selectFader(kind: controller.state.faderKind, index: $0) }
            )
            .onChange(of: faderIndexDraft) { _, newValue in
                applyIndexDraft(kind: controller.state.faderKind, draft: newValue) {
                    controller.selectFader(kind: controller.state.faderKind, index: $0)
                }
            }

            Text(RingOutPresenter.eqTargetHeading)
                .font(.custom("Inter", size: 13).weight(.semibold))
                .foregroundStyle(Theme.lightGold)
                .padding(.top, 8)
            kindRow(
                selected: controller.state.eqKind,
                set: { controller.selectEQ(kind: $0, index: clampedIndex($0, controller.state.eqIndex)) }
            )
            indexField(
                kind: controller.state.eqKind,
                draft: $eqIndexDraft,
                commit: { controller.selectEQ(kind: controller.state.eqKind, index: $0) }
            )
            .onChange(of: eqIndexDraft) { _, newValue in
                applyIndexDraft(kind: controller.state.eqKind, draft: newValue) {
                    controller.selectEQ(kind: controller.state.eqKind, index: $0)
                }
            }

            HStack(spacing: 12) {
                QuietButton(title: RingOutPresenter.startAction) { controller.start() }
                    .disabled(controller.state.loopLocked || controller.state.host.isEmpty || controller.state.port.isEmpty || !controller.state.rtaLive)
                if controller.state.undoAvailable {
                    QuietButton(title: RingOutPresenter.undoAction) { controller.undoNotches() }
                        .disabled(controller.state.loopLocked)
                }
            }
            .padding(.top, 8)

            if controller.state.loopLocked {
                Text(RingOutPresenter.modeLockNote)
                    .font(.custom("Inter", size: 12))
                    .foregroundStyle(Theme.secondary)
            }
        }
        .padding(ThemeMetrics.pagePadding)
        .disabled(controller.state.loopLocked)
    }

    private func kindRow(selected: StripKind, set: @escaping (StripKind) -> Void) -> some View {
        HStack(spacing: 10) {
            ForEach(StripKind.allCases, id: \.self) { kind in
                Button {
                    set(kind)
                } label: {
                    Text(RingOutPresenter.kindName(kind))
                        .font(.custom("Inter", size: 16).weight(.medium))
                        .foregroundStyle(selected == kind ? Theme.text : Theme.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(selected == kind ? Theme.selectedRow : Theme.raised)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected == kind ? Theme.gold : Theme.stroke))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func indexField(kind: StripKind, draft: Binding<String>, commit: @escaping (Int) -> Void) -> some View {
        let range = stripIndexRange(kind)
        return VStack(alignment: .leading, spacing: 6) {
            Text("Number (\(range.lowerBound)–\(range.upperBound))")
                .font(.custom("Inter", size: 11).weight(.medium))
                .foregroundStyle(Theme.secondary)
            TextField("\(range.lowerBound)", text: draft)
                .textFieldStyle(.plain)
                .font(.custom("Inter", size: 22).weight(.medium))
                .monospacedDigit()
                .padding(.horizontal, 14)
                .frame(maxWidth: 200)
                .frame(height: 52)
                .background(Theme.raised)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.stroke))
                .onSubmit { applyIndexDraft(kind: kind, draft: draft.wrappedValue, commit: commit) }
        }
    }

    private func applyIndexDraft(kind: StripKind, draft: String, commit: (Int) -> Void) {
        let digits = draft.filter(\.isNumber)
        guard let value = Int(digits), value > 0 else { return }
        let clamped = clampedIndex(kind, value)
        commit(clamped)
    }

    private func syncIndexDrafts() {
        faderIndexDraft = String(controller.state.faderIndex)
        eqIndexDraft = String(controller.state.eqIndex)
    }

    private func clampedIndex(_ kind: StripKind, _ index: Int) -> Int {
        let range = stripIndexRange(kind)
        return min(max(index, range.lowerBound), range.upperBound)
    }

    private func faderFraction(_ level: FaderLevel?) -> CGFloat {
        guard let level else { return 0 }
        switch level {
        case .minusInfinity:
            return 0
        case .decibels(let db):
            let clamped = min(10.0, max(-60.0, db))
            return CGFloat((clamped + 60.0) / 70.0)
        }
    }
}

struct RTAPlot: View {
    let points: [MagnitudePoint]
    let bands: [EqBand]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Canvas { context, size in
                let kept = points.filter { $0.hz >= 100 && $0.hz <= 8000 }
                var trace = Path()
                for (offset, point) in kept.enumerated() {
                    let spot = CGPoint(x: xPos(point.hz, width: size.width), y: yPos(point.db, height: size.height))
                    if offset == 0 { trace.move(to: spot) } else { trace.addLine(to: spot) }
                }
                context.stroke(trace, with: .color(Theme.live), lineWidth: 1.5)
                for band in bands where band.hz >= 100 && band.hz <= 8000 {
                    var mark = Path()
                    let x = xPos(band.hz, width: size.width)
                    mark.move(to: CGPoint(x: x, y: 0))
                    mark.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(mark, with: .color(Theme.gold), lineWidth: 2)
                }
            }
            .background(Theme.raised)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.stroke))
            HStack {
                Text(formatFrequency(100))
                Spacer()
                Text(formatFrequency(8000))
            }
            .font(.custom("Inter", size: 11))
            .foregroundStyle(Theme.dim)
        }
    }

    private func xPos(_ hz: Double, width: CGFloat) -> CGFloat {
        let lo = log10(100.0)
        let hi = log10(8000.0)
        let clamped = min(8000.0, max(100.0, hz))
        return CGFloat((log10(clamped) - lo) / (hi - lo)) * width
    }

    private func yPos(_ db: Double, height: CGFloat) -> CGFloat {
        let clamped = min(0.0, max(-80.0, db))
        return height - CGFloat((clamped + 80.0) / 80.0) * height
    }
}
