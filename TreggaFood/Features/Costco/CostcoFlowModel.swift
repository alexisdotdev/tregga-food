import Foundation
import Observation
import SwiftUI

/// Estado compartido del flujo Costco (Home → catálogo → carrito → checkout):
/// viaje + config + catálogo, y sincronización del carrito persistente.
@MainActor
@Observable
final class CostcoFlowModel {
    enum Phase: Equatable { case cargando, listo, error(String) }

    private(set) var phase: Phase = .cargando
    private(set) var estado: CostcoEstado?
    private(set) var catalogo: [CostcoProducto] = []
    /// Aviso de un solo uso (viaje cambió / productos quitados del carrito).
    var aviso: String?

    let repo: CostcoRepository

    init(repo: CostcoRepository) {
        self.repo = repo
    }

    var puedePedir: Bool { estado?.puedePedir == true }
    var config: CostcoConfig? { estado?.config }

    func cargar(cart: CostcoCartStore?) async {
        if estado == nil { phase = .cargando }
        do {
            async let e = repo.estado()
            async let c = repo.catalogo()
            let (nuevoEstado, nuevoCatalogo) = try await (e, c)
            estado = nuevoEstado
            catalogo = nuevoCatalogo
            phase = .listo
            switch cart?.sincronizar(estado: nuevoEstado, catalogo: nuevoCatalogo) {
            case .viajeCambio: aviso = CostcoCopy.carritoViajeCambio
            case .productosQuitados: aviso = CostcoCopy.carritoProductoQuitado
            case nil: break
            }
        } catch {
            // Fail-closed: sin estado no se puede pedir.
            if estado == nil { phase = .error((error as? CostcoError)?.mensaje ?? CostcoCopy.errorCarga) }
        }
    }

    func producto(_ id: UUID) -> CostcoProducto? { catalogo.first { $0.id == id } }
}

private struct CostcoCartKey: EnvironmentKey {
    static let defaultValue: CostcoCartStore? = nil
}

extension EnvironmentValues {
    var costcoCart: CostcoCartStore? {
        get { self[CostcoCartKey.self] }
        set { self[CostcoCartKey.self] = newValue }
    }
}
