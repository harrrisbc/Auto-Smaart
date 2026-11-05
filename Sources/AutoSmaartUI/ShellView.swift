import SwiftUI
import AutoSmaartPass
import AutoSmaartRingOut

public enum AppMode: Equatable {
    case calibration
    case ringOut
}

public struct ShellView: View {
    @Binding var mode: AppMode
    var calibration: PassController?
    @ObservedObject var ringOut: RingOutController

    public init(
        mode: Binding<AppMode>,
        calibration: PassController?,
        ringOut: RingOutController
    ) {
        self._mode = mode
        self.calibration = calibration
        self.ringOut = ringOut
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
                    })
                } else {
                    Color.clear
                }
            case .ringOut:
                RingOutPage(controller: ringOut, calibration: calibration) {
                    guard !ringOut.state.loopLocked else { return }
                    if let calibration {
                        ringOut.updateHost(calibration.state.host)
                        ringOut.updatePort(calibration.state.port)
                    }
                    mode = .calibration
                }
                .frame(width: ThemeMetrics.windowWidth, height: ThemeMetrics.windowHeight)
            }
        }
    }
}
