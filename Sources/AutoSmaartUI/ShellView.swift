import SwiftUI
import AutoSmaartCore
import AutoSmaartPass

public struct ShellView: View {
    @ObservedObject var controller: PassController

    public init(controller: PassController) {
        self.controller = controller
    }

    public var body: some View {
        VStack(spacing: 0) {
            titleBar
            selectors
            suggestion
            graph
        }
        .frame(width: ThemeMetrics.windowWidth, height: ThemeMetrics.windowHeight)
        .background(Theme.background)
        .foregroundStyle(Theme.text)
        .overlay { popupLayer }
        .onAppear {
            Theme.registerFonts()
            controller.refreshSessionFlag()
        }
    }

    private var titleBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Circle()
                    .fill(controller.state.smaartLive ? Theme.live : Theme.dim)
                    .frame(width: 8, height: 8)
                Text(PassPresenter.smaartConnectionLine(live: controller.state.smaartLive))
                    .font(.custom("Inter", size: 13))
                    .foregroundStyle(Theme.secondary)
            }
            Spacer()
            QuietButton(title: PassPresenter.settings) { openSettings() }
            QuietButton(title: PassPresenter.stop) { controller.stop() }
        }
        .padding(.horizontal, ThemeMetrics.pagePadding)
        .frame(height: ThemeMetrics.titleBar)
    }

    private var selectors: some View {
        HStack(alignment: .top, spacing: ThemeMetrics.groupGap) {
            selector(kicker: "Matrix", title: matrixTitle) { openMatrix() }
            selector(kicker: "EQ", title: presetTitle) { openPreset() }
        }
        .padding(.horizontal, ThemeMetrics.pagePadding)
        .padding(.top, 4)
    }

    private var suggestion: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(delayHeadline)
                        .font(.custom("Inter", size: 22).weight(.medium))
                        .monospacedDigit()
                    Text(PassPresenter.delaySupporting)
                        .font(.custom("Inter", size: 13))
                        .foregroundStyle(Theme.secondary)
                    Text(previousDelay)
                        .font(.custom("Inter", size: 13))
                        .foregroundStyle(Theme.secondary)
                }
                Spacer(minLength: 12)
                if PassPresenter.showsUndoDelay(controller.state) {
                    QuietButton(title: PassPresenter.undoDelay) { controller.undoDelay() }
                }
                if controller.state.notice == .couldNotRemeasure {
                    QuietButton(title: PassPresenter.retryRemeasure) { controller.retryRemeasure() }
                }
                actionButton(PassPresenter.readTrace, enabled: PassPresenter.readEnabled(controller.state)) {
                    controller.readTrace()
                }
                actionButton(PassPresenter.confirmDelay, enabled: PassPresenter.confirmDelayEnabled(controller.state)) {
                    controller.confirmDelay()
                }
            }
            HStack(spacing: 16) {
                Text(eqLine)
                    .font(.custom("Inter", size: 13))
                    .foregroundStyle(Theme.secondary)
                Spacer(minLength: 12)
                if PassPresenter.showsUndoLastWrite(controller.state) {
                    QuietButton(title: PassPresenter.undoLastWrite) { controller.undoLastWrite() }
                }
                actionButton(PassPresenter.confirmEq, enabled: PassPresenter.confirmEqEnabled(controller.state)) {
                    controller.confirmEq()
                }
            }
            Text(PassPresenter.confirmWarning)
                .font(.custom("Inter", size: 13))
                .foregroundStyle(Theme.secondary)
            if let notice = PassPresenter.noticeText(controller.state.notice) {
                Text(notice)
                    .font(.custom("Inter", size: 13))
                    .foregroundStyle(Theme.secondary)
            }
        }
        .padding(.horizontal, ThemeMetrics.pagePadding)
        .padding(.top, ThemeMetrics.groupGap)
    }

    private var graph: some View {
        let trace = PassPresenter.magnitudeTrace(controller.state)
        let bands = PassPresenter.graphBands(controller.state)
        return MagnitudePlot(
            before: trace,
            after: controller.state.afterCurve,
            bands: bands
        )
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.raised)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.stroke))
        .padding(ThemeMetrics.pagePadding)
    }

    @ViewBuilder private var popupLayer: some View {
        if controller.matrixPickerOpen {
            ZStack(alignment: .topLeading) {
                scrim { controller.matrixPickerOpen = false }
                matrixPopover
                    .padding(.top, 132)
                    .padding(.leading, ThemeMetrics.pagePadding)
            }
        } else if controller.presetPickerOpen {
            ZStack(alignment: .topTrailing) {
                scrim { controller.presetPickerOpen = false }
                presetPopover
                    .padding(.top, 132)
                    .padding(.trailing, ThemeMetrics.pagePadding)
            }
        } else if controller.settingsOpen {
            ZStack {
                scrim { controller.settingsOpen = false }
                settingsPanel
            }
        }
    }

    private func scrim(_ close: @escaping () -> Void) -> some View {
        Color.black.opacity(0.45)
            .contentShape(Rectangle())
            .onTapGesture(perform: close)
    }

    private var matrixTitle: String {
        if let index = controller.state.selectedOutput { return "Matrix \(index)" }
        return "Matrix"
    }

    private var presetTitle: String {
        controller.state.passPresetName ?? "EQ preset"
    }

    private var delayHeadline: String {
        if let shown = controller.state.displayedDelayMs { return PassPresenter.suggestedDelay(shown) }
        return PassPresenter.emDash
    }

    private var previousDelay: String {
        let snapshot = controller.state.selectedOutput.flatMap { index in
            controller.state.outputs.indices.contains(index - 1) ? controller.state.outputs[index - 1].delaySnapshot : nil
        }
        return PassPresenter.previousDelayLine(snapshot: snapshot)
    }

    private var eqLine: String {
        if let bands = controller.state.bands { return PassPresenter.eqSupporting(bandCount: bands.count) }
        if let preview = controller.state.previewBands { return PassPresenter.previewBandLine(count: preview.count) }
        return ""
    }

    private var matrixPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(1...12, id: \.self) { index in
                Button {
                    controller.selectOutput(index)
                    controller.matrixPickerOpen = false
                } label: {
                    HStack {
                        Text("Matrix \(index)")
                        Spacer()
                        if controller.state.selectedOutput == index {
                            Image(systemName: "checkmark").foregroundStyle(Theme.gold).font(.system(size: 11))
                        }
                    }
                    .font(.custom("Inter", size: 13))
                    .foregroundStyle(Theme.text)
                    .frame(height: ThemeMetrics.row)
                    .padding(.horizontal, 12)
                    .background(controller.state.selectedOutput == index ? Theme.selectedRow : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .frame(width: 240)
        .background(Theme.background)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.stroke))
    }

    private var presetPopover: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(controller.state.presets, id: \.name) { preset in
                    Button {
                        controller.recall(name: preset.name)
                        controller.presetPickerOpen = false
                    } label: {
                        CurveThumb(
                            points: preset.points,
                            selected: controller.state.passPresetName == preset.name,
                            label: preset.name
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
        .frame(width: 300, height: 380)
        .background(Theme.background)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.stroke))
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsView(controller: controller)
            QuietButton(title: PassPresenter.back) { controller.settingsOpen = false }
                .padding(.horizontal, ThemeMetrics.pagePadding)
                .padding(.bottom, ThemeMetrics.pagePadding)
        }
        .frame(width: 440, height: 560)
        .background(Theme.background)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.stroke))
    }

    private func selector(kicker: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(kicker)
                        .font(.custom("Inter", size: 11).weight(.medium))
                        .tracking(0.88)
                        .foregroundStyle(Theme.lightGold)
                    Text(title)
                        .font(.custom("Inter", size: 16).weight(.medium))
                        .foregroundStyle(Theme.text)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(Theme.raised)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.stroke))
        }
        .buttonStyle(.plain)
    }

    private func actionButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        PrimaryButton(title: title, action: action)
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.4)
    }

    private func openMatrix() {
        controller.presetPickerOpen = false
        controller.settingsOpen = false
        controller.matrixPickerOpen = true
    }

    private func openPreset() {
        controller.matrixPickerOpen = false
        controller.settingsOpen = false
        controller.presetPickerOpen = true
    }

    private func openSettings() {
        controller.matrixPickerOpen = false
        controller.presetPickerOpen = false
        controller.settingsOpen = true
    }
}
