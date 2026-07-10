import Foundation
import TreggaCore
import Supabase

/// Calificación del cliente al repartidor al completar el pedido (tabla `calificaciones`).
public protocol CalificacionRepository: Sendable {
    func calificar(
        pedidoId: UUID,
        clienteId: UUID?,
        repartidorId: UUID?,
        negocioId: UUID?,
        rating: Int,
        comment: String?,
        tags: [String]
    ) async throws

    /// Calificación que el cliente ya dio a este pedido (rated_by='cliente'), si existe.
    func fetchDelPedido(pedidoId: UUID) async throws -> PedidoCalificacion?
}

// MARK: - Supabase

public final class SupabaseCalificacionRepository: CalificacionRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient = SupabaseClientShared.client) {
        self.client = client
    }

    public func calificar(
        pedidoId: UUID,
        clienteId: UUID?,
        repartidorId: UUID?,
        negocioId: UUID?,
        rating: Int,
        comment: String?,
        tags: [String]
    ) async throws {
        struct Insert: Encodable {
            let pedido_id: String
            let cliente_id: String?
            let repartidor_id: String?
            // La reseña del cliente también califica al negocio: con negocio_id
            // aparece en la pantalla Reseñas de Tregga Business.
            let negocio_id: String?
            let rating: Int
            let comment: String?
            let tags: [String]
            let rated_by: String
        }
        try await client.from("calificaciones")
            .insert(Insert(
                pedido_id: pedidoId.uuidString,
                cliente_id: clienteId?.uuidString,
                repartidor_id: repartidorId?.uuidString,
                negocio_id: negocioId?.uuidString,
                rating: rating,
                comment: (comment?.isEmpty ?? true) ? nil : comment,
                tags: tags,
                rated_by: "cliente"
            ))
            .execute()
    }

    private struct CalificacionDTO: Decodable {
        let rating: Int
        let comment: String?
        let tags: [String]?
        let reply: String?
        let reply_at: Date?
    }

    public func fetchDelPedido(pedidoId: UUID) async throws -> PedidoCalificacion? {
        let dtos: [CalificacionDTO] = try await client.from("calificaciones")
            .select("rating,comment,tags,reply,reply_at")
            .eq("pedido_id", value: pedidoId.uuidString)
            .eq("rated_by", value: "cliente")
            .limit(1)
            .execute()
            .value
        guard let dto = dtos.first else { return nil }
        return PedidoCalificacion(
            rating: dto.rating,
            comment: dto.comment,
            tags: dto.tags ?? [],
            reply: dto.reply,
            replyAt: dto.reply_at
        )
    }
}

// MARK: - Mock

public final class MockCalificacionRepository: CalificacionRepository {
    public init() {}

    public func calificar(
        pedidoId: UUID,
        clienteId: UUID?,
        repartidorId: UUID?,
        negocioId: UUID?,
        rating: Int,
        comment: String?,
        tags: [String]
    ) async throws {
        try? await Task.sleep(nanoseconds: 400_000_000)
    }

    public func fetchDelPedido(pedidoId: UUID) async throws -> PedidoCalificacion? {
        nil
    }
}
