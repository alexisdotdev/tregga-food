import Foundation
import TreggaCore
import Supabase

/// Creación de pedidos del cliente vía RPC `crear_pedido_cliente` (F3).
public protocol PedidoRepository: Sendable {
    func crearPedido(
        clienteId: UUID,
        negocioId: UUID,
        direccionId: UUID,
        items: [PedidoItem],
        metodoPago: MetodoPago,
        deliveryFee: Decimal,
        propina: Decimal,
        notes: String?
    ) async throws -> ResultadoPedido
}

// MARK: - Supabase

public final class SupabasePedidoRepository: PedidoRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient = SupabaseClientShared.client) {
        self.client = client
    }

    private struct ModificadorJSON: Encodable {
        let nombre: String
        let precio_extra: Double
    }

    private struct ItemJSON: Encodable {
        let producto_id: String
        let nombre: String
        let cantidad: Int
        let precio_unitario: Double
        let modificadores: [ModificadorJSON]
        let subtotal: Double
    }

    private struct Params: Encodable {
        let p_cliente_id: String
        let p_negocio_id: String
        let p_direccion_id: String
        let p_items: [ItemJSON]
        let p_payment_method: String
        let p_delivery_fee: Double
        let p_propina: Double
        let p_notes: String?
    }

    struct ResultadoDTO: Decodable {
        let id: UUID
        let order_number: String?
        let amount: Double?
        let status: String?

        func toDomain() -> ResultadoPedido {
            ResultadoPedido(
                id: id,
                orderNumber: order_number ?? "",
                amount: Decimal(amount ?? 0),
                status: status ?? "pending"
            )
        }
    }

    public func crearPedido(
        clienteId: UUID,
        negocioId: UUID,
        direccionId: UUID,
        items: [PedidoItem],
        metodoPago: MetodoPago,
        deliveryFee: Decimal,
        propina: Decimal,
        notes: String?
    ) async throws -> ResultadoPedido {
        let itemsJSON = items.map { item in
            ItemJSON(
                producto_id: item.productoId.uuidString,
                nombre: item.nombre,
                cantidad: item.cantidad,
                precio_unitario: item.precioUnitario.doubleValue,
                modificadores: item.modificadores.map {
                    ModificadorJSON(nombre: $0.nombre, precio_extra: $0.precioExtra.doubleValue)
                },
                subtotal: item.subtotal.doubleValue
            )
        }
        let params = Params(
            p_cliente_id: clienteId.uuidString,
            p_negocio_id: negocioId.uuidString,
            p_direccion_id: direccionId.uuidString,
            p_items: itemsJSON,
            p_payment_method: metodoPago.rawValue,
            p_delivery_fee: deliveryFee.doubleValue,
            p_propina: propina.doubleValue,
            p_notes: notes
        )
        let dto: ResultadoDTO = try await client
            .rpc("crear_pedido_cliente", params: params)
            .execute()
            .value
        return dto.toDomain()
    }
}

// MARK: - Mock

public final class MockPedidoRepository: PedidoRepository {
    public init() {}

    public func crearPedido(
        clienteId: UUID,
        negocioId: UUID,
        direccionId: UUID,
        items: [PedidoItem],
        metodoPago: MetodoPago,
        deliveryFee: Decimal,
        propina: Decimal,
        notes: String?
    ) async throws -> ResultadoPedido {
        let subtotal = items.reduce(Decimal(0)) { $0 + $1.subtotal }
        return ResultadoPedido(
            id: UUID(),
            orderNumber: "TG-\(Int.random(in: 1000...9999))",
            amount: subtotal + deliveryFee + propina,
            status: "pending"
        )
    }
}

private extension Decimal {
    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }
}
