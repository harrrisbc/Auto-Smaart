import SwiftUI
import AutoSmaartPass

public struct CompareView: View {
    @ObservedObject var controller: PassController

    public init(controller: PassController) {
        self.controller = controller
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ThemeMetrics.groupGap) {
            Text(PassPresenter.compareTitle).font(.custom("Inter", size: 18).weight(.semibold))
            MagnitudePlot(before: controller.state.beforeCurve ?? [], after: controller.state.afterCurve)
            ForEach(PassPresenter.compareLines(controller.state), id: \.self) { line in
                Text(line).font(.custom("Inter", size: 13)).foregroundStyle(Theme.secondary)
            }
            Spacer()
        }
        .padding(ThemeMetrics.pagePadding)
    }
}
