import Foundation
import SwiftUI
import Observation

/// Una línea del carrito: producto + modificadores elegidos + cantidad + nota.
struct CartLine: Identifiable, Equatable {
    let id: UUID
    let producto: Producto
    var cantidad: Int
    let modificadores: [Modificador]
    var nota: String?

    /// Precio de una unidad (producto + extras de modificadores).
    var precioUnitario: Decimal {
        producto.precio + modificadores.reduce(Decimal(0)) { $0 + $1.precioExtra }
    }

    /// Subtotal de la línea = unitario * cantidad.
    var subtotal: Decimal { precioUnitario * Decimal(cantidad) }

    /// Resumen legible de modificadores: "Maciza · Tortillas extra".
    var modificadoresLabel: String {
        modificadores.map(\.nombre).joined(separator: " · ")
    }
}

/// Carrito de UN negocio a la vez. Si se agrega de otro negocio se solicita
/// confirmación (vía `pendingConflict`) antes de limpiar el actual.
@MainActor
@Observable
final class CartStore {
    private(set) var lines: [CartLine] = []
    private(set) var negocioId: UUID?
    private(set) var negocioName: String = ""

    /// Selección pendiente cuando el usuario intenta mezclar negocios.
    /// La UI presenta un diálogo; al confirmar llama `resolverConflicto(reemplazar:)`.
    private(set) var pendingConflict: PendingAdd?

    struct PendingAdd: Equatable {
        let selection: ProductSelection
        let negocioId: UUID
        let negocioName: String
        let nota: String?
    }

    var items: [CartLine] { lines }
    var count: Int { lines.reduce(0) { $0 + $1.cantidad } }
    var isEmpty: Bool { lines.isEmpty }

    var subtotal: Decimal {
        lines.reduce(Decimal(0)) { $0 + $1.subtotal }
    }

    /// Agrega una selección. Si el carrito tiene productos de otro negocio,
    /// registra el conflicto y NO agrega hasta que la UI lo resuelva.
    func add(selection: ProductSelection, negocioId: UUID, negocioName: String, nota: String? = nil) {
        if let actual = self.negocioId, actual != negocioId {
            pendingConflict = PendingAdd(
                selection: selection,
                negocioId: negocioId,
                negocioName: negocioName,
                nota: nota
            )
            return
        }
        appendLine(selection: selection, negocioId: negocioId, negocioName: negocioName, nota: nota)
    }

    /// Resuelve el conflicto de mezcla de negocios.
    /// - `reemplazar == true`: limpia el carrito y agrega la selección pendiente.
    /// - `reemplazar == false`: descarta la selección pendiente.
    func resolverConflicto(reemplazar: Bool) {
        guard let pending = pendingConflict else { return }
        pendingConflict = nil
        if reemplazar {
            clear()
            appendLine(
                selection: pending.selection,
                negocioId: pending.negocioId,
                negocioName: pending.negocioName,
                nota: pending.nota
            )
        }
    }

    func updateQty(lineId: UUID, cantidad: Int) {
        guard let idx = lines.firstIndex(where: { $0.id == lineId }) else { return }
        if cantidad <= 0 {
            lines.remove(at: idx)
        } else {
            lines[idx].cantidad = min(cantidad, 99)
        }
        if lines.isEmpty { reset() }
    }

    func increment(lineId: UUID) {
        guard let line = lines.first(where: { $0.id == lineId }) else { return }
        updateQty(lineId: lineId, cantidad: line.cantidad + 1)
    }

    func decrement(lineId: UUID) {
        guard let line = lines.first(where: { $0.id == lineId }) else { return }
        updateQty(lineId: lineId, cantidad: line.cantidad - 1)
    }

    func remove(lineId: UUID) {
        lines.removeAll { $0.id == lineId }
        if lines.isEmpty { reset() }
    }

    func clear() {
        lines.removeAll()
        reset()
    }

    /// Construye los items para la RPC de creación de pedido.
    func buildPedidoItems() -> [PedidoItem] {
        lines.map { line in
            PedidoItem(
                productoId: line.producto.id,
                nombre: line.producto.nombre,
                cantidad: line.cantidad,
                precioUnitario: line.precioUnitario,
                modificadores: line.modificadores.map {
                    PedidoItemModificador(nombre: $0.nombre, precioExtra: $0.precioExtra)
                },
                subtotal: line.subtotal
            )
        }
    }

    // MARK: - Internals

    private func appendLine(selection: ProductSelection, negocioId: UUID, negocioName: String, nota: String?) {
        self.negocioId = negocioId
        self.negocioName = negocioName
        // Mismo producto + mismos modificadores → suma cantidad.
        let modIds = Set(selection.modificadores.map(\.id))
        if let idx = lines.firstIndex(where: {
            $0.producto.id == selection.producto.id
                && Set($0.modificadores.map(\.id)) == modIds
                && $0.nota == nota
        }) {
            lines[idx].cantidad = min(lines[idx].cantidad + selection.cantidad, 99)
        } else {
            lines.append(CartLine(
                id: UUID(),
                producto: selection.producto,
                cantidad: selection.cantidad,
                modificadores: selection.modificadores,
                nota: nota
            ))
        }
    }

    private func reset() {
        negocioId = nil
        negocioName = ""
    }
}

// MARK: - Environment

private struct CartStoreKey: EnvironmentKey {
    @MainActor static let defaultValue: CartStore? = nil
}

extension EnvironmentValues {
    var cartStore: CartStore? {
        get { self[CartStoreKey.self] }
        set { self[CartStoreKey.self] = newValue }
    }
}
