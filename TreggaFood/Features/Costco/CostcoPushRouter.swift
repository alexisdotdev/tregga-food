import Foundation
import Observation

/// Push de Costco → pantalla (spec §5.1): `route` = `costco_pedido` | `costco_no_encontrado`,
/// `reference_id` = id del pedido. El shell presenta el detalle encima de la pestaña activa.
@MainActor
@Observable
final class CostcoPushRouter {
    static let shared = CostcoPushRouter()

    struct Destino: Identifiable, Equatable {
        let pedidoId: UUID
        let abrirNoEncontrado: Bool
        var id: UUID { pedidoId }
    }

    var pendiente: Destino?

    /// `nil` si el payload no es de Costco.
    nonisolated static func destino(from userInfo: [AnyHashable: Any]) -> Destino? {
        guard let route = userInfo["route"] as? String,
              let ref = userInfo["reference_id"] as? String,
              let id = UUID(uuidString: ref) else { return nil }
        switch route {
        case "costco_pedido": return Destino(pedidoId: id, abrirNoEncontrado: false)
        case "costco_no_encontrado": return Destino(pedidoId: id, abrirNoEncontrado: true)
        default: return nil
        }
    }

    nonisolated static func esCostco(_ userInfo: [AnyHashable: Any]) -> Bool { destino(from: userInfo) != nil }
}
