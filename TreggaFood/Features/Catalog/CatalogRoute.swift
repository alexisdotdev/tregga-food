import Foundation

/// Destinos de navegación dentro del tab Inicio.
enum CatalogRoute: Hashable {
    case restaurant(Negocio)
    case itemDetail(Producto, negocioName: String)
}
