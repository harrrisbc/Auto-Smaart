import SwiftUI
import AutoSmaartPass

public struct SettingsView: View {
    @ObservedObject var controller: PassController

    public init(controller: PassController) {
        self.controller = controller
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ThemeMetrics.groupGap) {
            Text(PassPresenter.settingsTitle).font(.custom("Inter", size: 18).weight(.semibold))
            Text(PassPresenter.settingsSupporting).font(.custom("Inter", size: 13)).foregroundStyle(Theme.secondary)

            Group {
                labeledField("Console IP", text: host)
                labeledField("OSC port", text: port)
                labeledField("Transfer function name", text: tfName, placeholder: "Blank = first active TF")
            }

            HStack {
                TextField("Curve name", text: draft)
                QuietButton(title: PassPresenter.storeTarget) { controller.storeTarget() }
                    .disabled(!PassPresenter.storeEnabled(controller.state))
                QuietButton(title: PassPresenter.storeTrace) { controller.storeTrace() }
                    .disabled(!PassPresenter.storeEnabled(controller.state))
            }
            .textFieldStyle(.plain)
            .font(.custom("Inter", size: 13))

            Spacer()
        }
        .padding(ThemeMetrics.pagePadding)
    }

    private var host: Binding<String> { Binding(get: { controller.state.host }, set: { controller.setHost($0) }) }
    private var port: Binding<String> { Binding(get: { controller.state.port }, set: { controller.setPort($0) }) }
    private var draft: Binding<String> { Binding(get: { controller.state.draftName }, set: { controller.setDraftName($0) }) }
    private var tfName: Binding<String> {
        Binding(get: { controller.state.transferFunctionName }, set: { controller.setTransferFunctionName($0) })
    }

    private func labeledField(_ title: String, text: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.custom("Inter", size: 11).weight(.medium))
                .tracking(0.88)
                .foregroundStyle(Theme.lightGold)
            TextField(placeholder.isEmpty ? title : placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.custom("Inter", size: 13))
                .frame(height: ThemeMetrics.row)
        }
    }
}
