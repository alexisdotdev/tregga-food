import Foundation
import TreggaCore
import Supabase

/// Creación de pedidos del cliente vía RPC `crear_pedido_cliente` (F3)
/// + lectura del historial y detalle de pedidos del cliente (F5).
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

    /// Historial completo del cliente, ordenado por fecha descendente.
    func fetchHistorial(clienteId: UUID) async throws -> [PedidoResumen]

    /// Detalle completo de un pedido (incluye items parseados).
    func fetchDetalle(pedidoId: UUID) async throws -> PedidoDetalle
}

// MARK: - Supabase

public final class SupabasePedidoRepository: PedidoRepository {
    private let client: SupabaseClient
    private let calificaciones: CalificacionRepository

    public init(
        client: SupabaseClient = SupabaseClientShared.client,
        calificaciones: CalificacionRepository = SupabaseCalificacionRepository()
    ) {
        self.client = client
        self.calificaciones = calificaciones
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
        let resultado = dto.toDomain()
        // Avisa al negocio (push) — best-effort: no bloquea ni falla el pedido.
        notificarNegocio(pedidoId: resultado.id)
        return resultado
    }

    /// POST best-effort a `notify-negocio` para que el dueño reciba el push del
    /// pedido nuevo aunque tenga la app cerrada. El endpoint resuelve el
    /// `owner_user_id` y manda FCM a sus `device_tokens`.
    private func notificarNegocio(pedidoId: UUID) {
        Task {
            guard let token = try? await client.auth.session.accessToken else { return }
            var req = URLRequest(url: Config.API_BASE.appendingPathComponent("api/pedidos/notify-negocio"))
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.httpBody = try? JSONSerialization.data(withJSONObject: ["pedido_id": pedidoId.uuidString])
            _ = try? await URLSession.shared.data(for: req)
        }
    }

    // MARK: - Historial / Detalle (F5)

    private struct ItemDTO: Decodable {
        let producto_id: String?
        let nombre: String?
        let cantidad: Int?
        let precio_unitario: Double?
        let modificadores: [ModDTO]?
        let subtotal: Double?

        struct ModDTO: Decodable {
            let nombre: String?
            let precio_extra: Double?
        }
    }

    private struct PedidoRowDTO: Decodable {
        let id: UUID
        let order_number: String?
        let negocio_id: UUID?
        let negocio_name: String?
        let repartidor_id: UUID?
        let repartidor_name: String?
        let status: String
        let items: [ItemDTO]?
        let subtotal: Double?
        let delivery_fee: Double?
        let propina: Double?
        let amount: Double?
        let payment_method: String?
        let payment_status: String?
        let delivery_address: String?
        let created_at: Date?
        let completed_at: Date?
        let cancelled_at: Date?
        let cancellation_reason: String?
    }

    private static let historialColumns =
        "id,order_number,negocio_name,status,items,amount,created_at"

    private static let detalleColumns =
        "id,order_number,negocio_id,negocio_name,repartidor_id,repartidor_name,status,items,subtotal,delivery_fee,propina,amount,payment_method,payment_status,delivery_address,created_at,completed_at,cancelled_at,cancellation_reason"

    public func fetchHistorial(clienteId: UUID) async throws -> [PedidoResumen] {
        let rows: [PedidoRowDTO] = try await client.from("pedidos")
            .select(Self.historialColumns)
            .eq("cliente_id", value: clienteId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.map { row in
            PedidoResumen(
                id: row.id,
                orderNumber: row.order_number ?? "",
                negocioName: row.negocio_name ?? "Pedido",
                itemsResumen: Self.resumenItems(row.items),
                total: Decimal(row.amount ?? 0),
                status: PedidoStatus(raw: row.status),
                fecha: row.created_at,
                rating: nil
            )
        }
    }

    public func fetchDetalle(pedidoId: UUID) async throws -> PedidoDetalle {
        let row: PedidoRowDTO = try await client.from("pedidos")
            .select(Self.detalleColumns)
            .eq("id", value: pedidoId.uuidString)
            .single()
            .execute()
            .value
        let calificacion = try? await calificaciones.fetchDelPedido(pedidoId: pedidoId)
        return Self.toDetalle(row, calificacion: calificacion)
    }

    private static func resumenItems(_ items: [ItemDTO]?) -> String {
        guard let items, !items.isEmpty else { return "Pedido sin detalle" }
        return items
            .map { "\($0.cantidad ?? 1)× \($0.nombre ?? "Producto")" }
            .joined(separator: ", ")
    }

    private static func toDetalle(_ row: PedidoRowDTO, calificacion: PedidoCalificacion?) -> PedidoDetalle {
        let parsedItems: [PedidoDetalleItem] = (row.items ?? []).map { item in
            PedidoDetalleItem(
                nombre: item.nombre ?? "Producto",
                cantidad: item.cantidad ?? 1,
                precioUnitario: Decimal(item.precio_unitario ?? 0),
                modificadores: (item.modificadores ?? []).compactMap { $0.nombre },
                subtotal: Decimal(item.subtotal ?? 0)
            )
        }
        return PedidoDetalle(
            id: row.id,
            orderNumber: row.order_number ?? "",
            status: PedidoStatus(raw: row.status),
            negocioName: row.negocio_name ?? "Negocio",
            negocioId: row.negocio_id,
            repartidorId: row.repartidor_id,
            repartidorName: row.repartidor_name,
            items: parsedItems,
            subtotal: Decimal(row.subtotal ?? 0),
            deliveryFee: Decimal(row.delivery_fee ?? 0),
            propina: Decimal(row.propina ?? 0),
            total: Decimal(row.amount ?? 0),
            metodoPago: MetodoPago(rawValue: row.payment_method ?? "efectivo") ?? .efectivo,
            paymentStatus: row.payment_status,
            deliveryAddress: row.delivery_address,
            fecha: row.created_at,
            completedAt: row.completed_at,
            cancelledAt: row.cancelled_at,
            cancellationReason: row.cancellation_reason,
            calificacion: calificacion
        )
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

    private static let activoId = UUID()
    private static let entregadoId = UUID()
    private static let canceladoId = UUID()

    public func fetchHistorial(clienteId: UUID) async throws -> [PedidoResumen] {
        try? await Task.sleep(nanoseconds: 300_000_000)
        return [
            PedidoResumen(
                id: Self.activoId,
                orderNumber: "TG-4821",
                negocioName: "Carnitas Don Lupe",
                itemsResumen: "2× Taco de surtida, 1× Agua de horchata",
                total: 248,
                status: .enEntrega,
                fecha: Date(),
                rating: nil
            ),
            PedidoResumen(
                id: Self.entregadoId,
                orderNumber: "TG-4790",
                negocioName: "Sushi Roll Express",
                itemsResumen: "1× Roll California, 1× Edamame",
                total: 312,
                status: .completed,
                fecha: Calendar.current.date(byAdding: .day, value: -2, to: Date()),
                rating: 5
            ),
            PedidoResumen(
                id: Self.canceladoId,
                orderNumber: "TG-4712",
                negocioName: "Pizza Forno",
                itemsResumen: "1× Pizza pepperoni grande",
                total: 199,
                status: .cancelled,
                fecha: Calendar.current.date(byAdding: .day, value: -6, to: Date()),
                rating: nil
            )
        ]
    }

    public func fetchDetalle(pedidoId: UUID) async throws -> PedidoDetalle {
        try? await Task.sleep(nanoseconds: 300_000_000)
        let status: PedidoStatus
        let negocio: String
        switch pedidoId {
        case Self.canceladoId: status = .cancelled; negocio = "Pizza Forno"
        case Self.activoId:    status = .enEntrega; negocio = "Carnitas Don Lupe"
        default:               status = .completed; negocio = "Sushi Roll Express"
        }
        let items = [
            PedidoDetalleItem(nombre: "Taco de surtida", cantidad: 2, precioUnitario: 38, modificadores: ["Con todo", "Salsa verde"], subtotal: 76),
            PedidoDetalleItem(nombre: "Agua de horchata", cantidad: 1, precioUnitario: 28, modificadores: [], subtotal: 28)
        ]
        let subtotal: Decimal = 104
        let deliveryFee: Decimal = 15
        let propina: Decimal = 25
        return PedidoDetalle(
            id: pedidoId,
            orderNumber: "TG-4821",
            status: status,
            negocioName: negocio,
            negocioId: UUID(),
            repartidorId: UUID(),
            repartidorName: "Miguel A.",
            items: items,
            subtotal: subtotal,
            deliveryFee: deliveryFee,
            propina: propina,
            total: subtotal + deliveryFee + propina,
            metodoPago: .efectivo,
            paymentStatus: "paid",
            deliveryAddress: "Av. Hidalgo 142, Centro",
            fecha: Date(),
            completedAt: status == .completed ? Date() : nil,
            cancelledAt: status == .cancelled ? Date() : nil,
            cancellationReason: status == .cancelled ? "El negocio se quedó sin producto." : nil,
            calificacion: pedidoId == Self.entregadoId
                ? PedidoCalificacion(rating: 5, comment: "Súper rápido", tags: ["Rapidísimo"])
                : nil
        )
    }
}

private extension Decimal {
    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }
}
