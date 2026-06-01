import Foundation

/// Notificación del usuario (tabla `notificaciones`).
/// Categorías de negocio: ofertas, pagos, promos, sistema.
public struct Notificacion: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let body: String?
    public let category: Categoria
    public let kind: Tipo
    public var read: Bool
    public let createdAt: Date?
    public let referenceType: String?

    public enum Categoria: String, Sendable, CaseIterable {
        case ofertas
        case pagos
        case promos
        case sistema

        /// Etiqueta corta para el "remitente" mostrado en la fila.
        public var remitente: String {
            switch self {
            case .ofertas: return "Tregga · Ofertas"
            case .pagos:   return "Tregga · Pagos"
            case .promos:  return "Tregga · Promos"
            case .sistema: return "Tregga"
            }
        }
    }

    public enum Tipo: String, Sendable {
        case info
        case alert
        case system
    }

    public init(
        id: UUID,
        title: String,
        body: String?,
        category: Categoria,
        kind: Tipo,
        read: Bool,
        createdAt: Date?,
        referenceType: String? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.category = category
        self.kind = kind
        self.read = read
        self.createdAt = createdAt
        self.referenceType = referenceType
    }

    /// "cuándo" legible en es-MX (relativo).
    public var cuando: String {
        guard let createdAt else { return "" }
        let cal = Calendar.current
        if cal.isDateInToday(createdAt) { return "Hoy" }
        if cal.isDateInYesterday(createdAt) { return "Ayer" }
        let days = cal.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
        if days < 7 { return "Hace \(days) días" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_MX")
        fmt.dateFormat = "d MMM"
        return fmt.string(from: createdAt)
    }
}
