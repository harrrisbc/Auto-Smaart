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
                curveList
            }
            Spacer()
        }
        .padding(ThemeMetrics.pagePadding)
    }

    private var matrixTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ForEach(CalibrationBusKind.allCases, id: \.self) { kind in
                    Button {
                        let index = controller.state.selectedOutput
                            .map { min(max($0, stripIndexRange(kind.stripKind).lowerBound), stripIndexRange(kind.stripKind).upperBound) }
                            ?? 1
                        controller.selectBus(kind: kind, index: index)
                    } label: {
                        Text(kind.label)
                            .font(.custom("Inter", size: 12).weight(.semibold))
                            .foregroundStyle(controller.state.busKind == kind ? Theme.text : Theme.secondary)
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(controller.state.busKind == kind ? Theme.selectedRow : Theme.raised)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.stroke))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.bottom, 8)
            header(controller.state.busKind.label, "Name", "Last write")
            ForEach(busRows, id: \.index) { row in
                Button { controller.selectBus(kind: controller.state.busKind, index: row.index) } label: {
                    HStack {
                        Text(PassPresenter.busLabel(kind: controller.state.busKind, index: row.index))
                            .frame(maxWidth: .infinity, alignment: .leading)
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

    private var busRows: [MatrixOutputRecord] {
        switch controller.state.busKind {
        case .matrix: return controller.state.outputs
        case .mix: return controller.state.mixOutputs
        }
    }

    private var curveList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Curve")
                .font(.custom("Inter", size: 11).weight(.medium))
                .tracking(0.88)
                .foregroundStyle(Theme.lightGold)
                .frame(height: ThemeMetrics.row, alignment: .leading)
            ForEach(controller.state.presets, id: \.name) { preset in
                Button { controller.recall(name: preset.name) } label: {
                    CurveThumb(
                        points: preset.points,
                        selected: controller.state.passPresetName == preset.name,
                        // Built-in shapes are distinct; only label bank/stored curves.
                        label: BuiltInTargets.names.contains(preset.name) ? nil : preset.name
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            get: {
                switch controller.state.busKind {
                case .matrix: return controller.state.outputs[index - 1].displayName
                case .mix: return controller.state.mixOutputs[index - 1].displayName
                }
            },
            set: { controller.setDisplayName($0, kind: controller.state.busKind, output: index) }
        )
    }
}
