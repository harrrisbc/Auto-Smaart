import SwiftUI
import AutoSmaartCore
import AutoSmaartPass

public struct PickView: View {
    @ObservedObject var controller: PassController

    public init(controller: PassController) {
        self.controller = controller
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ThemeMetrics.groupGap) {
            Text(PassPresenter.pickTitle).font(.custom("Inter", size: 18).weight(.semibold))
            Text(PassPresenter.pickSupporting).font(.custom("Inter", size: 13)).foregroundStyle(Theme.secondary)
            HStack(alignment: .top, spacing: ThemeMetrics.groupGap) {
                matrixTable
                curveTable
            }
            Spacer()
        }
        .padding(ThemeMetrics.pagePadding)
    }

    private var matrixTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            header("Matrix", "Name", "Last write")
            ForEach(controller.state.outputs, id: \.index) { row in
                Button { controller.selectOutput(row.index) } label: {
                    HStack {
                        Text("Matrix \(row.index)").frame(maxWidth: .infinity, alignment: .leading)
                        TextField("", text: name(row.index)).frame(maxWidth: .infinity)
                        Text(PassPresenter.lastWriteLabel(row.lastWrite)).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.custom("Inter", size: 13))
                    .frame(height: ThemeMetrics.row)
                    .padding(.leading, 8)
                    .background(controller.state.selectedOutput == row.index ? Theme.selectedRow : Color.clear)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(controller.state.selectedOutput == row.index ? Theme.gold : Color.clear).frame(width: 2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var curveTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            header("Curve", "Type", "Source")
            ForEach(controller.state.presets, id: \.name) { preset in
                Button { controller.recall(name: preset.name) } label: {
                    HStack {
                        Text(preset.name).frame(maxWidth: .infinity, alignment: .leading)
                        Text(PassPresenter.kindLabel(preset.kind)).frame(maxWidth: .infinity, alignment: .leading)
                        Text(curveSource(preset)).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.custom("Inter", size: 13))
                    .frame(height: ThemeMetrics.row)
                    .background(controller.state.passPresetName == preset.name ? Theme.selectedRow : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func curveSource(_ preset: CurvePreset) -> String {
        if BuiltInTargets.names.contains(preset.name) { return "Built-in" }
        return preset.kind == .target ? "Stored target" : "Captured trace"
    }

    private func header(_ a: String, _ b: String, _ c: String) -> some View {
        HStack {
            Text(a).frame(maxWidth: .infinity, alignment: .leading)
            Text(b).frame(maxWidth: .infinity, alignment: .leading)
            Text(c).frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.custom("Inter", size: 11).weight(.medium))
        .tracking(0.88)
        .foregroundStyle(Theme.lightGold)
        .frame(height: ThemeMetrics.row)
    }

    private func name(_ index: Int) -> Binding<String> {
        Binding(
            get: { controller.state.outputs[index - 1].displayName },
            set: { controller.setDisplayName($0, output: index) }
        )
    }
}
