import Foundation

enum AddressError: Error, Equatable {
    case outputOutOfRange
    case bandOutOfRange
}

public func delayAddresses(output: Int) throws -> (delay: String, fineDelay: String) {
    guard (1...12).contains(output) else { throw AddressError.outputOutOfRange }
    let prefix = "/sd/Matrix_Outputs/\(output)/Channel_Delay"
    return (prefix + "/delay", prefix + "/fine_delay")
}

public func eqAddresses(output: Int, band: Int) throws -> (freq: String, gain: String, q: String, on: String) {
    guard (1...12).contains(output) else { throw AddressError.outputOutOfRange }
    guard (1...8).contains(band) else { throw AddressError.bandOutOfRange }
    let prefix = "/sd/Matrix_Outputs/\(output)/EQ"
    return (prefix + "/eq_freq_\(band)", prefix + "/eq_gain_\(band)", prefix + "/eq_Q_\(band)", prefix + "/eq_on_\(band)")
}
