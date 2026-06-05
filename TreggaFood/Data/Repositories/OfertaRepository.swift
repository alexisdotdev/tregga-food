import Foundation
import TreggaCore
import Supabase

/// Lectura de promociones para el cliente. La RLS del backend ya filtra a las
/// activas y vigentes; aquí solo ordenamos por más recientes.
public protocol OfertaRepository: Sendable {
    func fetchActivas() async throws -> [Promocion]
}

// MARK: - Supabase

public final class SupabaseOfertaRepository: OfertaRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient = SupabaseClientShared.client) {
        self.client = client
    }

    struct PromocionDTO: Decodable {
        let id: UUID
        let negocio_id: UUID?
        let titulo: String
        let descripcion: String?
        let tag: String?
        let tipo: String
        let imagen_url: String?

        func toDomain() -> Promocion {
            Promocion(
                id: id,
                negocioId: negocio_id,
                titulo: titulo,
                descripcion: descripcion,
                tag: tag,
                tipo: tipo,
                imagenUrl: imagen_url
            )
        }
    }

    public func fetchActivas() async throws -> [Promocion] {
        let dtos: [PromocionDTO] = try await client.from("promociones")
            .select("id,negocio_id,titulo,descripcion,tag,tipo,imagen_url")
            .eq("activa", value: true)
            .order("created_at", ascending: false)
            .execute()
            .value
        return dtos.map { $0.toDomain() }
    }
}

// MARK: - Mock

public final class MockOfertaRepository: OfertaRepository {
    public init() {}

    public func fetchActivas() async throws -> [Promocion] {
        [
            Promocion(id: UUID(), negocioId: nil, titulo: "Envío gratis esta semana",
                      descripcion: "En negocios seleccionados de tu zona.", tag: "Envío $0", tipo: "envio_gratis"),
            Promocion(id: UUID(), negocioId: nil, titulo: "2x1 en postres",
                      descripcion: "Pide tu postre favorito y llévate otro gratis.", tag: "2x1", tipo: "dos_por_uno"),
            Promocion(id: UUID(), negocioId: nil, titulo: "$50 de descuento",
                      descripcion: "En tu primer pedido del mes, sin mínimo.", tag: "-$50", tipo: "descuento"),
        ]
    }
}
