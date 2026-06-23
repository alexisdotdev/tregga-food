import Foundation

/// Categoría del menú de un negocio (tabla `categorias_menu`).
public struct CategoriaMenu: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let negocioId: UUID
    public let nombre: String
    public let descripcion: String?
    public let displayOrder: Int

    public init(
        id: UUID,
        negocioId: UUID,
        nombre: String,
        descripcion: String? = nil,
        displayOrder: Int = 0
    ) {
        self.id = id
        self.negocioId = negocioId
        self.nombre = nombre
        self.descripcion = descripcion
        self.displayOrder = displayOrder
    }
}

/// Producto vendible (tabla `productos`).
public struct Producto: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let categoriaId: UUID
    public let negocioId: UUID
    public let nombre: String
    public let descripcion: String?
    public let precio: Decimal
    public let imageURL: String?
    public let isAvailable: Bool
    public let displayOrder: Int
    /// Franjas del día en que se sirve (desayuno/comida/cena). Vacío = todo el día.
    public let franjas: [String]

    public init(
        id: UUID,
        categoriaId: UUID,
        negocioId: UUID,
        nombre: String,
        descripcion: String? = nil,
        precio: Decimal,
        imageURL: String? = nil,
        isAvailable: Bool = true,
        displayOrder: Int = 0,
        franjas: [String] = []
    ) {
        self.id = id
        self.categoriaId = categoriaId
        self.negocioId = negocioId
        self.nombre = nombre
        self.descripcion = descripcion
        self.precio = precio
        self.imageURL = imageURL
        self.isAvailable = isAvailable
        self.displayOrder = displayOrder
        self.franjas = franjas
    }
}

/// Una sección del menú: categoría + sus productos disponibles.
public struct MenuSection: Identifiable, Equatable, Sendable {
    public var id: UUID { categoria.id }
    public let categoria: CategoriaMenu
    public let productos: [Producto]

    public init(categoria: CategoriaMenu, productos: [Producto]) {
        self.categoria = categoria
        self.productos = productos
    }
}

/// Grupo de modificadores de un producto (tabla `grupos_modificadores`).
/// `maxSelecciones == 1` → selección tipo radio; `> 1` → checkbox.
public struct GrupoModificadores: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let productoId: UUID
    public let nombre: String
    public let minSelecciones: Int
    public let maxSelecciones: Int
    public let displayOrder: Int
    public let modificadores: [Modificador]

    public init(
        id: UUID,
        productoId: UUID,
        nombre: String,
        minSelecciones: Int = 0,
        maxSelecciones: Int = 1,
        displayOrder: Int = 0,
        modificadores: [Modificador] = []
    ) {
        self.id = id
        self.productoId = productoId
        self.nombre = nombre
        self.minSelecciones = minSelecciones
        self.maxSelecciones = maxSelecciones
        self.displayOrder = displayOrder
        self.modificadores = modificadores
    }

    public var isRequired: Bool { minSelecciones >= 1 }
    public var isSingleChoice: Bool { maxSelecciones <= 1 }
}

/// Opción concreta dentro de un grupo (tabla `modificadores`).
public struct Modificador: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let grupoId: UUID
    public let nombre: String
    public let precioExtra: Decimal
    public let isAvailable: Bool
    public let displayOrder: Int

    public init(
        id: UUID,
        grupoId: UUID,
        nombre: String,
        precioExtra: Decimal = 0,
        isAvailable: Bool = true,
        displayOrder: Int = 0
    ) {
        self.id = id
        self.grupoId = grupoId
        self.nombre = nombre
        self.precioExtra = precioExtra
        self.isAvailable = isAvailable
        self.displayOrder = displayOrder
    }
}
