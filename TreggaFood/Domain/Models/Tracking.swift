import Foundation

/// Coordenada simple (lat/lng) usada por el tracking del cliente.
public struct TrackCoord: Equatable, Sendable {
    public let lat: Double
    public let lng: Double

    public init(lat: Double, lng: Double) {
        self.lat = lat
        self.lng = lng
    }
}

/// Estado del pedido en el flujo cliente (enum `pedido_status` del backend).
public enum PedidoStatus: String, Sendable, CaseIterable {
    case pending
    case assigned
    case enRecogida = "en_recogida"
    case recogido
    case enEntrega = "en_entrega"
    case completed
    case cancelled

    public init(raw: String) {
        self = PedidoStatus(rawValue: raw) ?? .pending
    }

    public var titulo: String {
        switch self {
        case .pending:     return "Buscando repartidor"
        case .assigned:    return "Repartidor asignado"
        case .enRecogida:  return "Pasando por tu pedido"
        case .recogido:    return "Va en camino"
        case .enEntrega:   return "Está llegando"
        case .completed:   return "Entregado"
        case .cancelled:   return "Cancelado"
        }
    }

    public var tagLabel: String {
        switch self {
        case .pending:     return "Confirmado"
        case .assigned:    return "Asignado"
        case .enRecogida:  return "En el negocio"
        case .recogido:    return "En camino"
        case .enEntrega:   return "Llegando"
        case .completed:   return "Entregado"
        case .cancelled:   return "Cancelado"
        }
    }

    public var isCompleted: Bool { self == .completed }
    public var isCancelled: Bool { self == .cancelled }
    public var isTerminal: Bool { isCompleted || isCancelled }

    /// El repartidor ya lleva el pedido y va hacia el cliente: es cuando tiene
    /// sentido dibujar la ruta hacia la casa y avisar de su aproximación.
    public var driverHeadingToClient: Bool { self == .recogido || self == .enEntrega }
}

/// Snapshot del pedido para la pantalla de tracking.
public struct PedidoTracking: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let orderNumber: String
    public let status: PedidoStatus
    public let repartidorId: UUID?
    public let repartidorName: String?
    public let negocioId: UUID?
    public let negocioName: String?
    public let pickup: TrackCoord?
    public let delivery: TrackCoord?
    public let estimatedDurationMin: Int?
    public let amount: Decimal
    /// Tipo de vehículo del repartidor (e.g. "moto", "motoneta", "bicicleta_electrica").
    /// Nil si no hay repartidor asignado o no se pudo obtener.
    public let vehiculoTipo: String?
    /// Momento en que el negocio aceptó el pedido. `nil` = el negocio aún no lo confirma.
    public let negocioConfirmedAt: Date?
    /// Motivo de cancelación (solo cuando `status == .cancelled`).
    public let cancellationReason: String?

    public init(
        id: UUID,
        orderNumber: String,
        status: PedidoStatus,
        repartidorId: UUID?,
        repartidorName: String?,
        negocioId: UUID? = nil,
        negocioName: String?,
        pickup: TrackCoord?,
        delivery: TrackCoord?,
        estimatedDurationMin: Int?,
        amount: Decimal,
        vehiculoTipo: String? = nil,
        negocioConfirmedAt: Date? = nil,
        cancellationReason: String? = nil
    ) {
        self.id = id
        self.orderNumber = orderNumber
        self.status = status
        self.repartidorId = repartidorId
        self.repartidorName = repartidorName
        self.negocioId = negocioId
        self.negocioName = negocioName
        self.pickup = pickup
        self.delivery = delivery
        self.estimatedDurationMin = estimatedDurationMin
        self.amount = amount
        self.vehiculoTipo = vehiculoTipo
        self.negocioConfirmedAt = negocioConfirmedAt
        self.cancellationReason = cancellationReason
    }

    /// El negocio todavía no acepta el pedido: fase previa a la búsqueda de repartidor.
    /// Mientras `status == .pending` sin `negocioConfirmedAt`, NO hay dispatch en curso
    /// (el `auto_assign` corre hasta que el negocio confirma).
    public var esperandoNegocio: Bool {
        status == .pending && negocioConfirmedAt == nil
    }

    /// El negocio no pudo tomar el pedido (rechazo o timeout), distinto de una
    /// cancelación por otra causa.
    public var canceladoPorNegocio: Bool {
        status == .cancelled
            && (cancellationReason == "negocio_timeout" || cancellationReason == "negocio_rechazo")
    }

    /// Etapa del timeline del cliente combinando las DOS máquinas de estado:
    /// [-1 Esperando negocio · 0 Confirmado · 1 Preparando · 2 En camino · 3 Entregado].
    /// En cuanto el negocio acepta (`negocioConfirmedAt`), el pedido está "Preparando"
    /// aunque el repartidor apenas vaya en camino al local (`assigned`). El `status`
    /// del enum solo describe al repartidor, por eso no basta con él.
    public var timelineStep: Int {
        switch status {
        case .completed:            return 3
        case .recogido, .enEntrega: return 2   // el repartidor ya lleva el pedido al cliente
        case .enRecogida:           return 1   // recogiendo en el negocio
        case .assigned:             return 1   // negocio preparando + repartidor asignado
        case .pending:              return negocioConfirmedAt == nil ? -1 : 1
        case .cancelled:            return 0
        }
    }

    /// Iniciales para el avatar del repartidor (e.g. "Miguel A." -> "MA").
    public var repartidorIniciales: String {
        guard let nombre = repartidorName, !nombre.isEmpty else { return "TG" }
        let partes = nombre.split(separator: " ").prefix(2)
        let iniciales = partes.compactMap { $0.first }.map(String.init).joined()
        return iniciales.isEmpty ? "TG" : iniciales.uppercased()
    }
}

/// Ubicación reportada por el repartidor.
public struct UbicacionRepartidor: Equatable, Sendable {
    public let coord: TrackCoord
    public let updatedAt: Date?

    public init(coord: TrackCoord, updatedAt: Date?) {
        self.coord = coord
        self.updatedAt = updatedAt
    }
}

/// Mensaje del chat entre cliente y repartidor.
public struct Mensaje: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let content: String
    public let senderRole: String
    public let fecha: Date
    public let esMio: Bool

    public init(id: UUID, content: String, senderRole: String, fecha: Date, esMio: Bool) {
        self.id = id
        self.content = content
        self.senderRole = senderRole
        self.fecha = fecha
        self.esMio = esMio
    }
}
