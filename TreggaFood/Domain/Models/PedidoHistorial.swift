import Foundation

/// Fila del historial de pedidos (lista "Mis pedidos", F5).
public struct PedidoResumen: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let orderNumber: String
    public let negocioName: String
    public let itemsResumen: String
    public let total: Decimal
    public let status: PedidoStatus
    public let fecha: Date?
    public let rating: Int?

    public init(
        id: UUID,
        orderNumber: String,
        negocioName: String,
        itemsResumen: String,
        total: Decimal,
        status: PedidoStatus,
        fecha: Date?,
        rating: Int?
    ) {
        self.id = id
        self.orderNumber = orderNumber
        self.negocioName = negocioName
        self.itemsResumen = itemsResumen
        self.total = total
        self.status = status
        self.fecha = fecha
        self.rating = rating
    }

    /// El pedido sigue en curso (no terminal).
    public var enCurso: Bool { !status.isTerminal }
}

/// Item del pedido ya parseado para el detalle (F5).
public struct PedidoDetalleItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    /// Id del producto original (para "Volver a pedir"). `nil` si el pedido
    /// es viejo y no lo trae el jsonb.
    public let productoId: UUID?
    public let nombre: String
    public let cantidad: Int
    public let precioUnitario: Decimal
    public let modificadores: [String]
    public let subtotal: Decimal

    public init(
        id: UUID = UUID(),
        productoId: UUID? = nil,
        nombre: String,
        cantidad: Int,
        precioUnitario: Decimal,
        modificadores: [String],
        subtotal: Decimal
    ) {
        self.id = id
        self.productoId = productoId
        self.nombre = nombre
        self.cantidad = cantidad
        self.precioUnitario = precioUnitario
        self.modificadores = modificadores
        self.subtotal = subtotal
    }
}

/// Calificación que el cliente ya dio a un pedido (tabla `calificaciones`).
public struct PedidoCalificacion: Equatable, Sendable {
    public let rating: Int
    public let comment: String?
    public let tags: [String]
    /// Respuesta del negocio a la reseña (`calificaciones.reply`). `nil` si no ha respondido.
    public let reply: String?
    public let replyAt: Date?

    public init(rating: Int, comment: String?, tags: [String], reply: String? = nil, replyAt: Date? = nil) {
        self.rating = rating
        self.comment = comment
        self.tags = tags
        self.reply = reply
        self.replyAt = replyAt
    }
}

/// Detalle completo de un pedido (pantalla "Detalle del pedido", F5).
public struct PedidoDetalle: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let orderNumber: String
    public let status: PedidoStatus
    public let negocioName: String
    public let negocioId: UUID?
    public let repartidorId: UUID?
    public let repartidorName: String?
    public let items: [PedidoDetalleItem]
    public let subtotal: Decimal
    public let deliveryFee: Decimal
    public let propina: Decimal
    /// Descuento aplicado (promo/cupón). 0 si no hubo.
    /// `amount = subtotal − descuento + deliveryFee + propina`.
    public let descuento: Decimal
    public let total: Decimal
    public let metodoPago: MetodoPago
    public let paymentStatus: String?
    public let deliveryAddress: String?
    public let fecha: Date?
    public let completedAt: Date?
    public let cancelledAt: Date?
    public let cancellationReason: String?
    public let calificacion: PedidoCalificacion?
    /// Momento en que el negocio aceptó el pedido. `nil` = el negocio aún no lo confirma.
    public let negocioConfirmedAt: Date?

    public init(
        id: UUID,
        orderNumber: String,
        status: PedidoStatus,
        negocioName: String,
        negocioId: UUID?,
        repartidorId: UUID?,
        repartidorName: String?,
        items: [PedidoDetalleItem],
        subtotal: Decimal,
        deliveryFee: Decimal,
        propina: Decimal,
        descuento: Decimal = 0,
        total: Decimal,
        metodoPago: MetodoPago,
        paymentStatus: String?,
        deliveryAddress: String?,
        fecha: Date?,
        completedAt: Date?,
        cancelledAt: Date?,
        cancellationReason: String?,
        calificacion: PedidoCalificacion?,
        negocioConfirmedAt: Date? = nil
    ) {
        self.id = id
        self.orderNumber = orderNumber
        self.status = status
        self.negocioName = negocioName
        self.negocioId = negocioId
        self.repartidorId = repartidorId
        self.repartidorName = repartidorName
        self.items = items
        self.subtotal = subtotal
        self.deliveryFee = deliveryFee
        self.propina = propina
        self.descuento = descuento
        self.total = total
        self.metodoPago = metodoPago
        self.paymentStatus = paymentStatus
        self.deliveryAddress = deliveryAddress
        self.fecha = fecha
        self.completedAt = completedAt
        self.cancelledAt = cancelledAt
        self.cancellationReason = cancellationReason
        self.calificacion = calificacion
        self.negocioConfirmedAt = negocioConfirmedAt
    }

    /// El pedido sigue en curso (no terminal) → permite seguir el tracking.
    public var enCurso: Bool { !status.isTerminal }

    /// El negocio todavía no acepta el pedido: fase previa a la búsqueda de repartidor.
    public var esperandoNegocio: Bool {
        status == .pending && negocioConfirmedAt == nil
    }

    /// El pedido lo canceló el negocio (rechazo, timeout o cancelación ya aceptado).
    public var canceladoPorNegocio: Bool {
        status == .cancelled
            && (cancellationReason == "negocio_timeout" || cancellationReason == "negocio_rechazo"
                || cancellationReason == "negocio_cancelo")
    }

    /// Título del banner de estado, combinando las dos máquinas de estado: mientras
    /// el negocio no confirma, `pending` NO es "Buscando repartidor" sino "Esperando
    /// al negocio"; una vez que acepta, el pedido está "En preparación".
    public var estadoTitulo: String {
        if esperandoNegocio { return "Esperando al negocio" }
        switch status {
        case .pending, .assigned: return "En preparación"
        default:                  return status.titulo
        }
    }
}
