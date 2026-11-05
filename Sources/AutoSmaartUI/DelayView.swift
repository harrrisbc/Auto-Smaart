import SwiftUI
import AutoSmaartPass

public struct DelayView: View {
    @ObservedObject var controller: PassController

    public init(controller: PassController) {
        self.controller = controller
    }

    public var body: some View {
        HStack(alignment: .top, spacing: ThemeMetrics.groupGap) {
            VStack(alignment: .leading) {
                MagnitudePlot(before: controller.state.latestMagnitude ?? [], after: nil)
                Text("Smaart delay read").font(.custom("Inter", size: 13)).foregroundStyle(Theme.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(PassPresenter.delayTitle).font(.custom("Inter", size: 18).weight(.semibold))
                Text(PassPresenter.delaySupporting).font(.custom("Inter", size: 13)).foregroundStyle(Theme.secondary)
                if let shown = controller.state.displayedDelayMs {
                    Text(PassPresenter.suggestedDelay(shown))
                        .font(.custom("Inter", size: 13).weight(.medium))
                        .monospacedDigit()
                }
                let snapshot = controller.state.selectedOutput.flatMap { index in
                    controller.state.outputs[index - 1].delaySnapshot
                }
                Text(PassPresenter.previousDelayLine(snapshot: snapshot))
                    .font(.custom("Inter", size: 13))
                    .foregroundStyle(Theme.secondary)
                Text(PassPresenter.confirmWarning).font(.custom("Inter", size: 13)).foregroundStyle(Theme.secondary)
                if PassPresenter.showsUndoDelay(controller.state) {
                    QuietButton(title: PassPresenter.undoDelay) { controller.undoDelay() }
                }
            }
            .padding(ThemeMetrics.pagePadding)
            .background(Theme.raised)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.stroke))
            Spacer()
        }
        .padding(ThemeMetrics.pagePadding)
    }
}
