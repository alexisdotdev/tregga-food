import Foundation

/// Formatea precios en pesos (es-MX) para el catálogo.
/// Los precios del catálogo llegan como `Decimal` de pesos (no centavos).
enum PriceFormat {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "es_MX")
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    static func pesos(_ value: Decimal) -> String {
        formatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0.00"
    }
}
