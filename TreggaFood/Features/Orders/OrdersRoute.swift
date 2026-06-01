import Foundation

/// Destinos de navegación dentro del tab Pedidos (historial → detalle → tracking/chat).
enum OrdersRoute: Hashable {
    case detalle(pedidoId: UUID)
    case tracking(pedidoId: UUID)
    case chat(pedidoId: UUID, repartidorName: String)
}
