import Foundation
import TreggaCore
import Supabase

public final class SupabaseCatalogRepository: CatalogRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient = SupabaseClientShared.client) {
        self.client = client
    }

    // MARK: - DTOs

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
                id: id,
                name: name,
                tipo: tipo,
                address: address,
                colonia: colonia,
                municipio: municipio,
                lat: lat,
                lng: lng,
                rating: rating ?? 0,
                totalOrders: total_orders ?? 0,
                tiempoPreparacionMin: tiempo_preparacion_min,
                descripcion: descripcion,
                logoURL: logo_url,
                coverImageURL: cover_image_url,
                aceptaPedidos: acepta_pedidos ?? true
            )
        }
    }

    struct CategoriaDTO: Decodable {
        let id: UUID
        let negocio_id: UUID
        let nombre: String
        let descripcion: String?
        let display_order: Int?

        func toDomain() -> CategoriaMenu {
            CategoriaMenu(
                id: id,
                negocioId: negocio_id,
                nombre: nombre,
                descripcion: descripcion,
                displayOrder: display_order ?? 0
            )
        }
    }

    struct ProductoDTO: Decodable {
        let id: UUID
        let categoria_id: UUID
        let negocio_id: UUID
        let nombre: String
        let descripcion: String?
        let precio: Double?
        let image_url: String?
        let is_available: Bool?
        let display_order: Int?

        func toDomain() -> Producto {
            Producto(
                id: id,
                categoriaId: categoria_id,
                negocioId: negocio_id,
                nombre: nombre,
                descripcion: descripcion,
                precio: Decimal(precio ?? 0),
                imageURL: image_url,
                isAvailable: is_available ?? true,
                displayOrder: display_order ?? 0
            )
        }
    }

    struct GrupoDTO: Decodable {
        let id: UUID
        let producto_id: UUID
        let nombre: String
        let min_selecciones: Int?
        let max_selecciones: Int?
        let display_order: Int?
    }

    struct ModificadorDTO: Decodable {
        let id: UUID
        let grupo_id: UUID
        let nombre: String
        let precio_extra: Double?
        let is_available: Bool?
        let display_order: Int?

        func toDomain() -> Modificador {
            Modificador(
                id: id,
                grupoId: grupo_id,
                nombre: nombre,
                precioExtra: Decimal(precio_extra ?? 0),
                isAvailable: is_available ?? true,
                displayOrder: display_order ?? 0
            )
        }
    }

    // MARK: - Queries

    public func fetchNegociosDisponibles() async throws -> [Negocio] {
        let dtos: [NegocioDTO] = try await client.from("negocios")
            .select()
            .eq("is_active", value: true)
            .eq("acepta_pedidos", value: true)
            .eq("status", value: "registered")
            .order("rating", ascending: false)
            .execute()
            .value
        return dtos.map { $0.toDomain() }
    }

    public func fetchMenu(negocioId: UUID) async throws -> [MenuSection] {
        async let categoriasTask: [CategoriaDTO] = client.from("categorias_menu")
            .select()
            .eq("negocio_id", value: negocioId.uuidString)
            .eq("is_active", value: true)
            .order("display_order", ascending: true)
            .execute()
            .value
        async let productosTask: [ProductoDTO] = client.from("productos")
            .select()
            .eq("negocio_id", value: negocioId.uuidString)
            .eq("is_available", value: true)
            .order("display_order", ascending: true)
            .execute()
            .value

        let categorias = try await categoriasTask
        let productos = try await productosTask

        let byCategoria = Dictionary(grouping: productos) { $0.categoria_id }
        return categorias.compactMap { cat -> MenuSection? in
            let items = (byCategoria[cat.id] ?? [])
                .map { $0.toDomain() }
                .sorted { $0.displayOrder < $1.displayOrder }
            guard !items.isEmpty else { return nil }
            return MenuSection(categoria: cat.toDomain(), productos: items)
        }
    }

    public func fetchModificadores(productoId: UUID) async throws -> [GrupoModificadores] {
        let grupos: [GrupoDTO] = try await client.from("grupos_modificadores")
            .select()
            .eq("producto_id", value: productoId.uuidString)
            .order("display_order", ascending: true)
            .execute()
            .value
        guard !grupos.isEmpty else { return [] }

        let grupoIds = grupos.map { $0.id.uuidString }
        let mods: [ModificadorDTO] = try await client.from("modificadores")
            .select()
            .in("grupo_id", values: grupoIds)
            .eq("is_available", value: true)
            .order("display_order", ascending: true)
            .execute()
            .value

        let byGrupo = Dictionary(grouping: mods) { $0.grupo_id }
        return grupos.map { g in
            let opciones = (byGrupo[g.id] ?? [])
                .map { $0.toDomain() }
                .sorted { $0.displayOrder < $1.displayOrder }
            return GrupoModificadores(
                id: g.id,
                productoId: g.producto_id,
                nombre: g.nombre,
                minSelecciones: g.min_selecciones ?? 0,
                maxSelecciones: g.max_selecciones ?? 1,
                displayOrder: g.display_order ?? 0,
                modificadores: opciones
            )
        }
    }
}
