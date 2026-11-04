import SwiftUI
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
                presetTable
            }
            HStack {
                TextField("Console IP", text: host)
                TextField("OSC port", text: port)
                TextField("Name", text: draft)
            }
            .textFieldStyle(.plain)
            .font(.custom("Inter", size: 13))
            HStack {
                QuietButton(title: PassPresenter.storeTarget) { controller.storeTarget() }
                    .disabled(!PassPresenter.storeEnabled(controller.state))
                QuietButton(title: PassPresenter.storeTrace) { controller.storeTrace() }
                    .disabled(!PassPresenter.storeEnabled(controller.state))
                QuietButton(title: PassPresenter.recall) { recallSelected() }
            }
            Spacer()
        }
        .padding(ThemeMetrics.pagePadding)
    }

    private var host: Binding<String> { Binding(get: { controller.state.host }, set: { controller.setHost($0) }) }
    private var port: Binding<String> { Binding(get: { controller.state.port }, set: { controller.setPort($0) }) }
    private var draft: Binding<String> { Binding(get: { controller.state.draftName }, set: { controller.setDraftName($0) }) }

    private var matrixTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            header("Output", "Name", "Last write")
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

    private var presetTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            header("Preset", "Type", "Source")
            ForEach(controller.state.presets, id: \.name) { preset in
                Button { controller.recall(name: preset.name) } label: {
                    HStack {
                        Text(preset.name).frame(maxWidth: .infinity, alignment: .leading)
                        Text(PassPresenter.kindLabel(preset.kind)).frame(maxWidth: .infinity, alignment: .leading)
                        Text(preset.kind == .target ? "Smaart target" : "Captured trace").frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.custom("Inter", size: 13))
                    .frame(height: ThemeMetrics.row)
                    .background(controller.state.passPresetName == preset.name ? Theme.selectedRow : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
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

    private func recallSelected() {
        if let name = controller.state.passPresetName { controller.recall(name: name) }
    }
}
