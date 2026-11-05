import SwiftUI
import AutoSmaartPass
import AutoSmaartRingOut
import ConsoleOSC

public enum AppMode: Equatable {
    case calibration
    case ringOut
}

public struct ShellView: View {
    @Binding var mode: AppMode
    var calibration: PassController?
    @ObservedObject var ringOut: RingOutController
    var muteLink: OscLink?

    public init(
        mode: Binding<AppMode>,
        calibration: PassController?,
        ringOut: RingOutController,
        muteLink: OscLink? = nil
    ) {
        self._mode = mode
        self.calibration = calibration
        self.ringOut = ringOut
        self.muteLink = muteLink
    }

    public var body: some View {
        Group {
            switch mode {
            case .calibration:
                if let calibration {
                    CalibrationShell(controller: calibration, onRingOut: {
                        guard !ringOut.state.loopLocked else { return }
                        ringOut.updateHost(calibration.state.host)
                        ringOut.updatePort(calibration.state.port)
                        mode = .ringOut
                    }, onStopMute: {
                        if let muteLink { _ = muteAll(link: muteLink) }
                    })
                } else {
                    Color.clear
                }
            case .ringOut:
                RingOutPage(controller: ringOut) {
                    guard !ringOut.state.loopLocked else { return }
                    mode = .calibration
                }
                .frame(width: ThemeMetrics.windowWidth, height: ThemeMetrics.windowHeight)
            }
        }
    }
}
