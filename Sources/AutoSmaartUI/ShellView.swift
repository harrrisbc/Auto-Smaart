import SwiftUI
import AutoSmaartPass

public struct ShellView: View {
    @ObservedObject var controller: PassController

    public init(controller: PassController) {
        self.controller = controller
    }

    public var body: some View {
        VStack(spacing: 0) {
            titleBar
            HStack(spacing: 0) {
                rail
                screen
            }
            bottomBar
        }
        .frame(width: ThemeMetrics.windowWidth, height: ThemeMetrics.windowHeight)
        .background(Theme.background)
        .foregroundStyle(Theme.text)
        .onAppear { Theme.registerFonts() }
    }

    private var titleBar: some View {
        HStack {
            Text("Auto-Smaart")
                .font(.custom("Playfair Display", size: 18).italic())
                .padding(.leading, 78)
            Text("Quantum 225")
                .font(.custom("Inter", size: 13))
                .foregroundStyle(Theme.secondary)
            Spacer()
            HStack(spacing: 8) {
                Circle().fill(controller.state.smaartLive ? Theme.live : Theme.dim).frame(width: 8, height: 8)
                Text(PassPresenter.smaartLabel).font(.custom("Inter", size: 13)).foregroundStyle(Theme.secondary)
                Text(PassPresenter.oscStatus(armed: PassPresenter.oscArmed(controller.state)))
                    .font(.custom("Inter", size: 13))
                    .foregroundStyle(Theme.secondary)
            }
            .padding(.trailing, ThemeMetrics.pagePadding)
        }
        .frame(height: ThemeMetrics.titleBar)
    }

    private var rail: some View {
        VStack(alignment: .leading, spacing: 0) {
            railRow(.pick, title: "Pick", done: controller.canOpen(.delay))
            railRow(.delay, title: "Delay", done: controller.state.delayWrittenThisPass)
            railRow(.eq, title: "EQ", done: controller.state.compareOpen)
            railRow(.compare, title: "Compare", done: false)
            Spacer()
        }
        .frame(width: ThemeMetrics.rail)
        .background(Theme.raised)
    }

    private func railRow(_ step: PassStep, title: String, done: Bool) -> some View {
        Button { controller.openRail(step) } label: {
            HStack {
                Rectangle().fill(controller.state.step == step ? Theme.gold : Color.clear).frame(width: 2)
                Text(title)
                    .font(.custom("Inter", size: 13).weight(.medium))
                    .foregroundStyle(controller.state.step == step ? Theme.lightGold : Theme.dim)
                Spacer()
                if done { Image(systemName: "checkmark").foregroundStyle(Theme.gold).font(.system(size: 11)) }
            }
            .frame(height: ThemeMetrics.row)
        }
        .buttonStyle(.plain)
        .disabled(!controller.canOpen(step))
    }

    @ViewBuilder private var screen: some View {
        switch controller.state.step {
        case .pick: PickView(controller: controller)
        case .delay: DelayView(controller: controller)
        case .eq: EQView(controller: controller)
        case .compare: CompareView(controller: controller)
        }
    }

    private var bottomBar: some View {
        HStack {
            Text(PassPresenter.selectionSummary(controller.state))
                .font(.custom("Inter", size: 13))
                .foregroundStyle(Theme.secondary)
            Spacer()
            if let notice = PassPresenter.noticeText(controller.state.notice) {
                Text(notice).font(.custom("Inter", size: 13)).foregroundStyle(Theme.secondary)
            }
            bottomAction
        }
        .padding(.horizontal, ThemeMetrics.pagePadding)
        .frame(height: ThemeMetrics.bottomBar)
    }

    @ViewBuilder private var bottomAction: some View {
        switch controller.state.step {
        case .pick:
            PrimaryButton(title: PassPresenter.readTrace) { controller.readTrace() }
                .disabled(!PassPresenter.readEnabled(controller.state))
        case .delay:
            HStack(spacing: 16) {
                QuietButton(title: PassPresenter.back) { controller.back() }
                if controller.state.notice == .couldNotRemeasure {
                    QuietButton(title: PassPresenter.retryRemeasure) { controller.retryRemeasure() }
                }
                PrimaryButton(title: PassPresenter.confirmDelay) { controller.confirmDelay() }
                    .disabled(!PassPresenter.confirmDelayEnabled(controller.state))
            }
        case .eq:
            PrimaryButton(title: PassPresenter.confirmEq) { controller.confirmEq() }
                .disabled(!PassPresenter.confirmEqEnabled(controller.state))
        case .compare:
            if PassPresenter.showsUndoLastWrite(controller.state) {
                QuietButton(title: PassPresenter.undoLastWrite) { controller.undoLastWrite() }
            }
        }
    }
}
