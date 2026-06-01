import Foundation

/// Método de pago soportado al crear un pedido (enum `payment_method` del backend).
public enum MetodoPago: String, CaseIterable, Sendable, Identifiable {
    case efectivo
    case transferencia
    case tarjeta

    public var id: String { rawValue }

    public var titulo: String {
        switch self {
        case .efectivo:      return "Efectivo"
        case .transferencia: return "Transferencia SPEI"
        case .tarjeta:       return "Tarjeta"
        }
    }

    public var subtitulo: String {
        switch self {
        case .efectivo:      return "Pagas al recibir · llévalo justo"
        case .transferencia: return "Subes tu comprobante después de confirmar"
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
