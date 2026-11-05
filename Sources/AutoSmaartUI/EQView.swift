import SwiftUI
import AutoSmaartPass
import AutoSmaartCore

public struct EQView: View {
    @ObservedObject var controller: PassController

    public init(controller: PassController) {
        self.controller = controller
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ThemeMetrics.groupGap) {
            Text(PassPresenter.eqTitle).font(.custom("Inter", size: 18).weight(.semibold))
            Text(PassPresenter.eqSupporting(bandCount: controller.state.bands?.count ?? 0))
                .font(.custom("Inter", size: 13)).foregroundStyle(Theme.secondary)
            VStack(spacing: 0) {
                ForEach(1...8, id: \.self) { index in
                    let band = controller.state.bands?.first { $0.index == index }
                    HStack {
                        Text("\(index)").frame(width: 40, alignment: .leading)
                        Text(PassPresenter.frequencyCell(band)).frame(maxWidth: .infinity, alignment: .leading)
                        Text(PassPresenter.gainCell(band)).frame(maxWidth: .infinity, alignment: .leading)
                        Text(PassPresenter.qCell(band)).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.custom("Inter", size: 13).weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(band == nil ? Theme.dim : Theme.text)
                    .frame(height: ThemeMetrics.row)
                }
            }
            Text(PassPresenter.eqUndoNote(hasSnapshot: controller.state.selectedOutput.flatMap { controller.state.outputs[$0 - 1].eqSnapshot } != nil))
                .font(.custom("Inter", size: 13)).foregroundStyle(Theme.secondary)
            Text(PassPresenter.confirmWarning).font(.custom("Inter", size: 13)).foregroundStyle(Theme.secondary)
            Spacer()
        }
        .padding(ThemeMetrics.pagePadding)
    }
}
