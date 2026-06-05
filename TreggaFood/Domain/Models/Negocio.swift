import Foundation

/// Negocio listable en el catálogo de Tregga Food (cliente).
/// Refleja la tabla `negocios` (subset relevante para discovery + restaurante).
public struct Negocio: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let tipo: String?
    public let address: String?
    public let colonia: String?
    public let municipio: String?
    public let lat: Double?
    public let lng: Double?
    public let rating: Double
    public let totalOrders: Int
    public let tiempoPreparacionMin: Int?
    public let descripcion: String?
    public let logoURL: String?
    public let coverImageURL: String?
    public let aceptaPedidos: Bool

    public init(
        id: UUID,
        name: String,
        tipo: String? = nil,
        address: String? = nil,
        colonia: String? = nil,
        municipio: String? = nil,
        lat: Double? = nil,
        lng: Double? = nil,
        rating: Double = 0,
        totalOrders: Int = 0,
        tiempoPreparacionMin: Int? = nil,
        descripcion: String? = nil,
        logoURL: String? = nil,
        coverImageURL: String? = nil,
        aceptaPedidos: Bool = true
    ) {
        self.id = id
        self.name = name
        self.tipo = tipo
        self.address = address
        self.colonia = colonia
        self.municipio = municipio
        self.lat = lat
        self.lng = lng
        self.rating = rating
        self.totalOrders = totalOrders
        self.tiempoPreparacionMin = tiempoPreparacionMin
        self.descripcion = descripcion
        self.logoURL = logoURL
        self.coverImageURL = coverImageURL
        self.aceptaPedidos = aceptaPedidos
    }

    /// Línea de meta para FoodCard: "20–30 min".
    public var tiempoLabel: String {
        guard let min = tiempoPreparacionMin, min > 0 else { return "Tiempo por confirmar" }
        return "\(min)–\(min + 10) min"
    }

    public var ratingLabel: String {
        rating > 0 ? String(format: "%.1f", rating) : "Nuevo"
    }
}
