import Foundation

/// Método de pago soportado al crear un pedido (enum `payment_method` del backend).
public enum MetodoPago: String, CaseIterable, Sendable, Identifiable {
    case efectivo
    case transferencia
    case tarjeta

    public var id: String { rawValue }

    /// Métodos ofrecidos hoy al cliente. La tarjeta (Stripe) queda fuera hasta
    /// integrar la pasarela en una sesión posterior; el caso del enum se conserva
    /// porque el backend ya lo soporta.
    public static let seleccionables: [MetodoPago] = [.efectivo, .transferencia]

    public var titulo: String {
        switch self {
        case .efectivo:      return "Efectivo"
        case .transferencia: return "Transferencia"
        case .tarjeta:       return "Tarjeta"
        }
    }

    public var subtitulo: String {
        switch self {
        case .efectivo:      return "Le pagas en efectivo al repartidor al recibir"
        case .transferencia: return "Le transfieres al repartidor al recibir"
        case .tarjeta:       return "Pasarela en configuración"
        }
    }
}

/// Resultado de crear un pedido vía RPC `crear_pedido_cliente`.
public struct ResultadoPedido: Equatable, Sendable {
    public let id: UUID
    public let orderNumber: String
    public let amount: Decimal
    public let status: String

    public init(id: UUID, orderNumber: String, amount: Decimal, status: String) {
        self.id = id
        self.orderNumber = orderNumber
        self.amount = amount
        self.status = status
    }
}

/// Item del pedido listo para serializar al JSON que espera la RPC.
public struct PedidoItem: Equatable, Sendable {
    public let productoId: UUID
    public let nombre: String
    public let cantidad: Int
    public let precioUnitario: Decimal
    public let modificadores: [PedidoItemModificador]
    public let subtotal: Decimal

    public init(
        productoId: UUID,
        nombre: String,
        cantidad: Int,
        precioUnitario: Decimal,
        modificadores: [PedidoItemModificador],
        subtotal: Decimal
    ) {
        self.productoId = productoId
        self.nombre = nombre
        self.cantidad = cantidad
        self.precioUnitario = precioUnitario
        self.modificadores = modificadores
        self.subtotal = subtotal
    }
}

public struct PedidoItemModificador: Equatable, Sendable {
    public let nombre: String
    public let precioExtra: Decimal

    public init(nombre: String, precioExtra: Decimal) {
        self.nombre = nombre
        self.precioExtra = precioExtra
    }
}
