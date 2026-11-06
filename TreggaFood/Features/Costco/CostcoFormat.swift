import Foundation

/// Fechas y porcentajes de Costco, siempre en hora de CDMX (spec §5.1).
/// `fechaCorta` → "vie 14 nov" · `fechaHora` → "mié 12 nov, 11:59 p.m."
enum CostcoFormat {
    static let zona = TimeZone(identifier: "America/Mexico_City")!

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.timeZone = zona
        f.dateFormat = format
        return f
    }

    private static let corta = formatter("EEE d MMM")
    private static let hora = formatter("h:mm a")
    private static let dia: DateFormatter = {
        let f = formatter("yyyy-MM-dd")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func fechaCorta(_ date: Date) -> String { limpiar(corta.string(from: date)) }

    /// Para `fecha_viaje` ("YYYY-MM-DD", sin hora).
    static func fechaCorta(dia s: String) -> String {
        guard let d = dia.date(from: s) else { return s }
        return fechaCorta(d.addingTimeInterval(12 * 3600))
    }

    static func fechaHora(_ date: Date) -> String {
        "\(fechaCorta(date)), \(hora.string(from: date).lowercased())"
    }

    static func pct(_ d: Decimal) -> String {
        NSDecimalNumber(decimal: d).stringValue
    }

    /// es_MX a veces abrevia con punto ("vie.", "nov."): el contrato de copy va sin puntos.
    private static func limpiar(_ s: String) -> String { s.replacingOccurrences(of: ".", with: "") }
}
