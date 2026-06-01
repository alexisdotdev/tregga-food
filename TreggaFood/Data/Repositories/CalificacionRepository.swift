import Foundation
import TreggaCore
import Supabase

/// Calificación del cliente al repartidor al completar el pedido (tabla `calificaciones`).
public protocol CalificacionRepository: Sendable {
    func calificar(
        pedidoId: UUID,
        clienteId: UUID?,
        repartidorId: UUID?,
        rating: Int,
        comment: String?,
        tags: [String]
    ) async throws
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
        rating: Int,
        comment: String?,
        tags: [String]
    ) async throws {
        struct Insert: Encodable {
            let pedido_id: String
            let cliente_id: String?
            let repartidor_id: String?
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
                rating: rating,
                comment: (comment?.isEmpty ?? true) ? nil : comment,
                tags: tags,
                rated_by: "cliente"
            ))
            .execute()
    }
}

// MARK: - Mock

public final class MockCalificacionRepository: CalificacionRepository {
    public init() {}

    public func calificar(
        pedidoId: UUID,
        clienteId: UUID?,
        repartidorId: UUID?,
        rating: Int,
        comment: String?,
        tags: [String]
    ) async throws {
        try? await Task.sleep(nanoseconds: 400_000_000)
    }
}
