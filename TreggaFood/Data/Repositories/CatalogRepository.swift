import Foundation

/// Catálogo de discovery + menú para la app de cliente (F2).
public protocol CatalogRepository: Sendable {
    /// Negocios listables en el Home: activos, aceptando pedidos y registrados.
    func fetchNegociosDisponibles() async throws -> [Negocio]
    /// Menú de un negocio agrupado por categoría (solo categorías/productos activos).
    func fetchMenu(negocioId: UUID) async throws -> [MenuSection]
    /// Grupos de modificadores (con sus opciones) de un producto.
    func fetchModificadores(productoId: UUID) async throws -> [GrupoModificadores]
    /// Horarios de atención del negocio (para mostrar abierto/cerrado).
    func fetchHorarios(negocioId: UUID) async throws -> [HorarioNegocio]
}

// MARK: - Mock

public final class MockCatalogRepository: CatalogRepository {
    public init() {}

    private static let donLupeId = UUID()
    private static let mamaRosaId = UUID()
    private static let charalId = UUID()

    public func fetchNegociosDisponibles() async throws -> [Negocio] {
        [
            Negocio(
                id: Self.donLupeId,
                name: "Carnitas Don Lupe",
                tipo: "Carnitas · Michoacana",
                address: "Av. Hidalgo 142, Centro",
                colonia: "Centro",
                municipio: "Zinapécuaro",
                lat: 19.8640,
                lng: -100.8230,
                rating: 4.9,
                totalOrders: 2400,
                tiempoPreparacionMin: 20,
                descripcion: "Las carnitas más pedidas del pueblo, servidas con tortillas hechas a mano.",
                aceptaPedidos: true
            ),
            Negocio(
                id: Self.charalId,
                name: "Tacos El Charal",
                tipo: "Tacos · Antojitos",
                address: "Calle Allende 56, Centro",
                colonia: "Centro",
                municipio: "Zinapécuaro",
                lat: 19.8662,
                lng: -100.8208,
                rating: 4.7,
                totalOrders: 3100,
                tiempoPreparacionMin: 15,
                descripcion: "Tacos al pastor y antojitos rapidísimos.",
                aceptaPedidos: true
            ),
            Negocio(
                id: Self.mamaRosaId,
                name: "La Cocina de Mamá Rosa",
                tipo: "Casera · Comida corrida",
                address: "Calle Morelos 89, San Antonio",
                colonia: "San Antonio",
                municipio: "Zinapécuaro",
                lat: 19.8625,
                lng: -100.8246,
                rating: 4.8,
                totalOrders: 1100,
                tiempoPreparacionMin: 25,
                descripcion: "Comida casera como la de casa.",
                aceptaPedidos: true
            ),
        ]
    }

    public func fetchMenu(negocioId: UUID) async throws -> [MenuSection] {
        let catMasPedido = UUID()
        let catAcomp = UUID()
        let catBebidas = UUID()
        return [
            MenuSection(
                categoria: CategoriaMenu(id: catMasPedido, negocioId: negocioId, nombre: "Más pedido", displayOrder: 0),
                productos: [
                    Producto(id: Self.tacoId, categoriaId: catMasPedido, negocioId: negocioId, nombre: "Taco de carnitas", descripcion: "Maciza, cuero o surtido. Cebolla y cilantro.", precio: 22, displayOrder: 0),
                    Producto(id: Self.ordenId, categoriaId: catMasPedido, negocioId: negocioId, nombre: "Orden de carnitas ¼ kg", descripcion: "Para 2 personas. Incluye tortillas y salsas.", precio: 165, displayOrder: 1),
                    Producto(id: UUID(), categoriaId: catMasPedido, negocioId: negocioId, nombre: "Gordita rellena", descripcion: "Carnitas, queso, frijoles refritos.", precio: 38, displayOrder: 2),
                ]
            ),
            MenuSection(
                categoria: CategoriaMenu(id: catAcomp, negocioId: negocioId, nombre: "Acompañamientos", displayOrder: 1),
                productos: [
                    Producto(id: UUID(), categoriaId: catAcomp, negocioId: negocioId, nombre: "Frijoles charros", descripcion: "Con tocino y chorizo.", precio: 45, displayOrder: 0),
                    Producto(id: UUID(), categoriaId: catAcomp, negocioId: negocioId, nombre: "Guacamole con totopos", descripcion: "Receta de la casa.", precio: 55, displayOrder: 1),
                ]
            ),
            MenuSection(
                categoria: CategoriaMenu(id: catBebidas, negocioId: negocioId, nombre: "Bebidas", displayOrder: 2),
                productos: [
                    Producto(id: UUID(), categoriaId: catBebidas, negocioId: negocioId, nombre: "Agua de horchata 1 L", descripcion: "Hecha en casa.", precio: 45, displayOrder: 0),
                    Producto(id: UUID(), categoriaId: catBebidas, negocioId: negocioId, nombre: "Coca-Cola 600 ml", precio: 28, displayOrder: 1),
                ]
            ),
        ]
    }

    public func fetchHorarios(negocioId: UUID) async throws -> [HorarioNegocio] {
        // Lun–Sáb 11:00–22:00, Dom 11:00–18:00.
        (1...7).map { dia in
            HorarioNegocio(diaSemana: dia, horaApertura: "11:00",
                           horaCierre: dia == 7 ? "18:00" : "22:00", isActive: true)
        }
    }

    private static let tacoId = UUID()
    private static let ordenId = UUID()

    public func fetchModificadores(productoId: UUID) async throws -> [GrupoModificadores] {
        let grupoCarne = UUID()
        let grupoExtras = UUID()
        return [
            GrupoModificadores(
                id: grupoCarne, productoId: productoId, nombre: "Elige tu tipo de carne",
                minSelecciones: 1, maxSelecciones: 1, displayOrder: 0,
                modificadores: [
                    Modificador(id: UUID(), grupoId: grupoCarne, nombre: "Maciza", precioExtra: 0, displayOrder: 0),
                    Modificador(id: UUID(), grupoId: grupoCarne, nombre: "Cuero", precioExtra: 0, displayOrder: 1),
                    Modificador(id: UUID(), grupoId: grupoCarne, nombre: "Surtido", precioExtra: 0, displayOrder: 2),
                    Modificador(id: UUID(), grupoId: grupoCarne, nombre: "Costilla", precioExtra: 15, displayOrder: 3),
                ]
            ),
            GrupoModificadores(
                id: grupoExtras, productoId: productoId, nombre: "Extras (opcional)",
                minSelecciones: 0, maxSelecciones: 3, displayOrder: 1,
                modificadores: [
                    Modificador(id: UUID(), grupoId: grupoExtras, nombre: "Tortillas extra", precioExtra: 12, displayOrder: 0),
                    Modificador(id: UUID(), grupoId: grupoExtras, nombre: "Guacamole de la casa", precioExtra: 25, displayOrder: 1),
                    Modificador(id: UUID(), grupoId: grupoExtras, nombre: "Frijoles charros", precioExtra: 30, displayOrder: 2),
                ]
            ),
        ]
    }
}
