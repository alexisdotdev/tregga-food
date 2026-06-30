import Foundation
import TreggaCore
import Supabase

/// Lectura del estado del pedido y de la ubicación del repartidor (F4).
public protocol TrackingRepository: Sendable {
    func fetchPedido(id: UUID) async throws -> PedidoTracking
    func fetchUbicacionRepartidor(repartidorId: UUID) async throws -> UbicacionRepartidor?
    /// El pedido en curso del cliente (no terminal), si existe.
    func fetchPedidoActivo(clienteId: UUID) async throws -> PedidoTracking?
    /// Teléfono del repartidor del pedido (para llamar/WhatsApp). Vía RPC
    /// `SECURITY DEFINER`: solo lo devuelve a quien participa en el pedido.
    func telefonoRepartidor(pedidoId: UUID) async throws -> String?
}

// MARK: - Supabase

public final class SupabaseTrackingRepository: TrackingRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient = SupabaseClientShared.client) {
        self.client = client
    }

    struct PedidoDTO: Decodable {
        let id: UUID
        let order_number: String?
        let status: String
        let repartidor_id: UUID?
        let repartidor_name: String?
        let negocio_id: UUID?
        let negocio_name: String?
        let pickup_lat: Double?
        let pickup_lng: Double?
        let delivery_lat: Double?
        let delivery_lng: Double?
        let estimated_duration_min: Int?
        let amount: Double?

        func toDomain(vehiculoTipo: String? = nil) -> PedidoTracking {
            let pickup: TrackCoord? = {
                guard let la = pickup_lat, let lo = pickup_lng else { return nil }
                return TrackCoord(lat: la, lng: lo)
            }()
            let delivery: TrackCoord? = {
                guard let la = delivery_lat, let lo = delivery_lng else { return nil }
                return TrackCoord(lat: la, lng: lo)
            }()
            return PedidoTracking(
                id: id,
                orderNumber: order_number ?? "",
                status: PedidoStatus(raw: status),
                repartidorId: repartidor_id,
                repartidorName: repartidor_name,
                negocioId: negocio_id,
                negocioName: negocio_name,
                pickup: pickup,
                delivery: delivery,
                estimatedDurationMin: estimated_duration_min,
                amount: Decimal(amount ?? 0),
                vehiculoTipo: vehiculoTipo
            )
        }
    }

    struct VehiculoTipoRow: Decodable { let tipo: String? }

    struct RepartidorLocationDTO: Decodable {
        let current_lat: Double?
        let current_lng: Double?
        let last_location_at: Date?
    }

    private static let columns =
        "id,order_number,status,repartidor_id,repartidor_name,negocio_id,negocio_name,pickup_lat,pickup_lng,delivery_lat,delivery_lng,estimated_duration_min,amount"

    public func fetchPedido(id: UUID) async throws -> PedidoTracking {
        let dto: PedidoDTO = try await client.from("pedidos")
            .select(Self.columns)
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        let tipo = dto.repartidor_id != nil ? await fetchVehiculoTipo(repartidorId: dto.repartidor_id!) : nil
        return dto.toDomain(vehiculoTipo: tipo)
    }

    private func fetchVehiculoTipo(repartidorId: UUID) async -> String? {
        let rows: [VehiculoTipoRow] = (try? await client.from("vehiculos")
            .select("tipo")
            .eq("repartidor_id", value: repartidorId.uuidString)
            .limit(1)
            .execute()
            .value) ?? []
        return rows.first?.tipo
    }

    public func fetchUbicacionRepartidor(repartidorId: UUID) async throws -> UbicacionRepartidor? {
        let dtos: [RepartidorLocationDTO] = try await client.from("repartidores")
            .select("current_lat,current_lng,last_location_at")
            .eq("id", value: repartidorId.uuidString)
            .limit(1)
            .execute()
            .value
        guard let dto = dtos.first, let la = dto.current_lat, let lo = dto.current_lng else { return nil }
        return UbicacionRepartidor(coord: TrackCoord(lat: la, lng: lo), updatedAt: dto.last_location_at)
    }

    public func fetchPedidoActivo(clienteId: UUID) async throws -> PedidoTracking? {
        let dtos: [PedidoDTO] = try await client.from("pedidos")
            .select(Self.columns)
            .eq("cliente_id", value: clienteId.uuidString)
            .neq("status", value: "completed")
            .neq("status", value: "cancelled")
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        guard let dto = dtos.first else { return nil }
        let tipo = dto.repartidor_id != nil ? await fetchVehiculoTipo(repartidorId: dto.repartidor_id!) : nil
        return dto.toDomain(vehiculoTipo: tipo)
    }

    public func telefonoRepartidor(pedidoId: UUID) async throws -> String? {
        struct Params: Encodable { let p_pedido_id: String }
        let phone: String? = try await client
            .rpc("get_repartidor_phone", params: Params(p_pedido_id: pedidoId.uuidString))
            .execute()
            .value
        return phone
    }
}

// MARK: - Mock

/// Mock con un repartidor que se mueve poco a poco del pickup al destino.
public final class MockTrackingRepository: TrackingRepository {
    private actor Counter {
        private var tick = 0
        func next() -> Int { let v = tick; tick += 1; return v }
        func current() -> Int { tick }
    }
    private let pickup = TrackCoord(lat: 19.8530, lng: -100.8210)
    private let delivery = TrackCoord(lat: 19.8480, lng: -100.8290)
    private let repartidorId = UUID()
    private let counter = Counter()

    public init() {}

    public func fetchPedido(id: UUID) async throws -> PedidoTracking {
        let t = await counter.next()
        let status: PedidoStatus = {
            switch t {
            case 0...1:  return .assigned
            case 2...3:  return .enRecogida
            case 4...5:  return .recogido
            case 6...9:  return .enEntrega
            default:     return .completed
            }
        }()
        return PedidoTracking(
            id: id,
            orderNumber: "TG-4821",
            status: status,
            repartidorId: repartidorId,
            repartidorName: "Miguel A.",
            negocioName: "Carnitas Don Lupe",
            pickup: pickup,
            delivery: delivery,
            estimatedDurationMin: max(2, 12 - t),
            amount: 248
        )
    }

    public func fetchUbicacionRepartidor(repartidorId: UUID) async throws -> UbicacionRepartidor? {
        let t = min(await counter.current(), 10)
        let f = Double(t) / 10.0
        let lat = pickup.lat + (delivery.lat - pickup.lat) * f
        let lng = pickup.lng + (delivery.lng - pickup.lng) * f
        return UbicacionRepartidor(coord: TrackCoord(lat: lat, lng: lng), updatedAt: Date())
    }

    public func fetchPedidoActivo(clienteId: UUID) async throws -> PedidoTracking? {
        try await fetchPedido(id: UUID())
    }

    public func telefonoRepartidor(pedidoId: UUID) async throws -> String? {
        "+525555555555"
    }
}
