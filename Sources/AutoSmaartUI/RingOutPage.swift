import SwiftUI
import Combine
import AutoSmaartRingOut
import AutoSmaartCore

public struct RingOutPage: View {
    @ObservedObject var controller: RingOutController
    let onLeave: () -> Void
    @State private var showPopup = false

    public init(controller: RingOutController, onLeave: @escaping () -> Void) {
        self.controller = controller
        self.onLeave = onLeave
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(RingOutPresenter.statusText(
                    rtaLive: controller.state.rtaLive,
                    notice: controller.state.notice,
                    host: controller.state.host,
                    port: controller.state.port
                ))
                .font(.custom("Inter", size: 13))
                .foregroundStyle(Theme.secondary)
                Spacer()
                QuietButton(title: RingOutPresenter.stopAction) { controller.stop() }
            }
            .frame(height: ThemeMetrics.titleBar)
            .padding(.horizontal, ThemeMetrics.pagePadding)

            HStack(alignment: .top, spacing: 20) {
                fader
                    .frame(width: 120, height: 280)
                Spacer()
                Button {
                    showPopup = true
                } label: {
                    Text(RingOutPresenter.targetLabel(
                        faderKind: controller.state.faderKind,
                        faderIndex: controller.state.faderIndex,
                        eqKind: controller.state.eqKind,
                        eqIndex: controller.state.eqIndex
                    ))
                    .font(.custom("Inter", size: 16).weight(.medium))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(Theme.raised)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.stroke))
                }
                .buttonStyle(.plain)
                .disabled(controller.state.loopLocked)
                .popover(isPresented: $showPopup) { popup }
            }
            .padding(ThemeMetrics.pagePadding)

            RTAPlot(points: controller.state.latestRTA, bands: controller.state.bands)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, ThemeMetrics.pagePadding)
                .padding(.bottom, ThemeMetrics.pagePadding)
        }
        .background(Theme.background)
        .foregroundStyle(Theme.text)
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { date in
            controller.tick(now: date)
        }
    }

    private var fader: some View {
        VStack(spacing: 12) {
            Text(RingOutPresenter.faderCell(controller.state.currentFader))
                .font(.custom("Inter", size: 22).weight(.semibold))
                .monospacedDigit()
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4).fill(Theme.raised)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.live)
                        .frame(height: geo.size.height * faderFraction(controller.state.currentFader))
                }
            }
        }
    }

    private var popup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(RingOutPresenter.faderTargetHeading)
                .font(.custom("Inter", size: 11).weight(.medium))
                .foregroundStyle(Theme.lightGold)
            kindPicker(
                kind: controller.state.faderKind,
                index: controller.state.faderIndex,
                set: { controller.selectFader(kind: $0, index: $1) }
            )
            Text(RingOutPresenter.eqTargetHeading)
                .font(.custom("Inter", size: 11).weight(.medium))
                .foregroundStyle(Theme.lightGold)
            kindPicker(
                kind: controller.state.eqKind,
                index: controller.state.eqIndex,
                set: { controller.selectEQ(kind: $0, index: $1) }
            )
            QuietButton(title: RingOutPresenter.startAction) {
                controller.start()
                showPopup = false
            }
            .disabled(controller.state.loopLocked || controller.state.host.isEmpty || controller.state.port.isEmpty || !controller.state.rtaLive)
            if controller.state.undoAvailable {
                QuietButton(title: RingOutPresenter.undoAction) { controller.undoNotches() }
                    .disabled(controller.state.loopLocked)
            }
            QuietButton(title: RingOutPresenter.leaveAction, action: onLeave)
                .disabled(controller.state.loopLocked)
            if controller.state.loopLocked {
                Text(RingOutPresenter.modeLockNote)
                    .font(.custom("Inter", size: 11))
                    .foregroundStyle(Theme.secondary)
            }
        }
        .padding(16)
        .frame(width: 280)
        .background(Theme.background)
    }

    private func kindPicker(kind: StripKind, index: Int, set: @escaping (StripKind, Int) -> Void) -> some View {
        HStack {
            Picker(RingOutPresenter.faderTargetHeading, selection: Binding(
                get: { kind },
                set: { set($0, stripIndexRange($0).lowerBound) }
            )) {
                ForEach(StripKind.allCases, id: \.self) { item in
                    Text(RingOutPresenter.kindName(item)).tag(item)
                }
            }
            .labelsHidden()
            Picker("Index", selection: Binding(
                get: { index },
                set: { set(kind, $0) }
            )) {
                ForEach(Array(stripIndexRange(kind)), id: \.self) { item in
                    Text("\(item)").tag(item)
                }
            }
            .labelsHidden()
        }
        .disabled(controller.state.loopLocked)
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
