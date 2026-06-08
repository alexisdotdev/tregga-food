import Foundation
import TreggaCore
import Supabase

/// Favoritos del cliente (tabla `favoritos`). Cada fila enlaza un usuario con un
/// negocio. La RLS limita todo a `user_id = auth.uid()`.
public protocol FavoritoRepository: Sendable {
    /// Negocios marcados como favoritos, más recientes primero.
    func listar(userId: UUID) async throws -> [Negocio]
    /// IDs de negocios favoritos (para pintar el corazón rápido).
    func idsFavoritos(userId: UUID) async throws -> Set<UUID>
    func agregar(userId: UUID, negocioId: UUID) async throws
    func quitar(userId: UUID, negocioId: UUID) async throws
}

// MARK: - Supabase

public final class SupabaseFavoritoRepository: FavoritoRepository {
    private let client: SupabaseClient
    public init(client: SupabaseClient = SupabaseClientShared.client) { self.client = client }

    private static let negocioCols =
        "id,name,tipo,address,colonia,municipio,lat,lng,rating,total_orders,tiempo_preparacion_min,descripcion,logo_url,cover_image_url,acepta_pedidos"

    struct NegocioDTO: Decodable {
        let id: UUID
        let name: String
        let tipo: String?
        let address: String?
        let colonia: String?
        let municipio: String?
        let lat: Double?
        let lng: Double?
        let rating: Double?
        let total_orders: Int?
        let tiempo_preparacion_min: Int?
        let descripcion: String?
        let logo_url: String?
        let cover_image_url: String?
        let acepta_pedidos: Bool?

        func toDomain() -> Negocio {
            Negocio(
                id: id, name: name, tipo: tipo, address: address, colonia: colonia,
                municipio: municipio, lat: lat, lng: lng, rating: rating ?? 0,
                totalOrders: total_orders ?? 0, tiempoPreparacionMin: tiempo_preparacion_min,
                descripcion: descripcion, logoURL: logo_url, coverImageURL: cover_image_url,
                aceptaPedidos: acepta_pedidos ?? true
            )
        }
    }

    public func listar(userId: UUID) async throws -> [Negocio] {
        struct Row: Decodable { let negocios: NegocioDTO? }
        let rows: [Row] = try await client.from("favoritos")
            .select("negocios(\(Self.negocioCols))")
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.compactMap { $0.negocios?.toDomain() }
    }

    public func idsFavoritos(userId: UUID) async throws -> Set<UUID> {
        struct Row: Decodable { let negocio_id: UUID }
        let rows: [Row] = try await client.from("favoritos")
            .select("negocio_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        return Set(rows.map { $0.negocio_id })
    }

    public func agregar(userId: UUID, negocioId: UUID) async throws {
        struct Row: Encodable { let user_id: String; let negocio_id: String }
        try await client.from("favoritos")
            .upsert(Row(user_id: userId.uuidString, negocio_id: negocioId.uuidString),
                    onConflict: "user_id,negocio_id")
            .execute()
    }

    public func quitar(userId: UUID, negocioId: UUID) async throws {
        try await client.from("favoritos")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("negocio_id", value: negocioId.uuidString)
            .execute()
    }
}

// MARK: - Mock

public final class MockFavoritoRepository: FavoritoRepository {
    public init() {}
    private var ids: Set<UUID> = []
    public func listar(userId: UUID) async throws -> [Negocio] { [] }
    public func idsFavoritos(userId: UUID) async throws -> Set<UUID> { ids }
    public func agregar(userId: UUID, negocioId: UUID) async throws { ids.insert(negocioId) }
    public func quitar(userId: UUID, negocioId: UUID) async throws { ids.remove(negocioId) }
}
