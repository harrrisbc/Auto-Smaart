import Foundation

public func roundHalfAwayFromZero(_ value: Double, places: Int) -> Double {
    let source = Decimal(string: String(value)) ?? Decimal(value)
    let behavior = NSDecimalNumberHandler(
        roundingMode: .plain,
        scale: Int16(places),
        raiseOnExactness: false,
        raiseOnOverflow: false,
        raiseOnUnderflow: false,
        raiseOnDivideByZero: false
    )
    return NSDecimalNumber(decimal: source).rounding(accordingToBehavior: behavior).doubleValue
}
