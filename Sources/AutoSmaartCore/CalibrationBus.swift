import Foundation

/// Calibration page bus choice. Mix maps to Digico Aux mixes.
public enum CalibrationBusKind: String, Equatable, Codable, CaseIterable {
    case mix
    case matrix

    public var label: String {
        switch self {
        case .mix: return "Mix"
        case .matrix: return "Matrix"
        }
    }

    public var indexRange: ClosedRange<Int> {
        switch self {
        case .mix: return 1...24
        case .matrix: return 1...12
        }
    }

    public var oscPrefix: String {
        switch self {
        case .mix: return "/sd/Aux_Outputs"
        case .matrix: return "/sd/Matrix_Outputs"
        }
    }
}
