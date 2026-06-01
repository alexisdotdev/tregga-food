import Foundation

/// Destinos de navegación dentro del tab Inicio.
enum CatalogRoute: Hashable {
    case restaurant(Negocio)
    case itemDetail(Producto, negocioName: String)
    case cart
    case checkout
    case tracking(pedidoId: UUID)
    case chat(pedidoId: UUID, repartidorName: String)
}
