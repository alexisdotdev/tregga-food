import Foundation
import Observation

/// Selección concreta de un producto con sus modificadores + cantidad.
struct ProductSelection: Equatable {
    let producto: Producto
    let cantidad: Int
    let modificadores: [Modificador]
    let total: Decimal
}

@MainActor
@Observable
final class ItemDetailViewModel {
    enum State: Equatable {
        case loading
        case ready([GrupoModificadores])
        case error(String)
    }

    let producto: Producto
    private(set) var state: State = .loading
    var cantidad: Int = 1
    /// grupoId → set de modificadorIds seleccionados.
    private(set) var seleccion: [UUID: Set<UUID>] = [:]

    private let repository: CatalogRepository
    private var grupos: [GrupoModificadores] = []

    init(producto: Producto, repository: CatalogRepository) {
        self.producto = producto
        self.repository = repository
    }

    func load() async {
        state = .loading
        do {
            grupos = try await repository.fetchModificadores(productoId: producto.id)
            preseleccionarObligatorios()
            state = .ready(grupos)
        } catch {
            state = .error("No pudimos cargar las opciones. Intenta de nuevo.")
        }
    }

    private func preseleccionarObligatorios() {
        for grupo in grupos where grupo.isSingleChoice && grupo.isRequired {
            if let first = grupo.modificadores.first(where: { $0.isAvailable }) {
                seleccion[grupo.id] = [first.id]
            }
        }
    }

    func isSelected(grupo: GrupoModificadores, modificador: Modificador) -> Bool {
        seleccion[grupo.id]?.contains(modificador.id) ?? false
    }

    func toggle(grupo: GrupoModificadores, modificador: Modificador) {
        var current = seleccion[grupo.id] ?? []
        if grupo.isSingleChoice {
            // Opcional (no obligatorio): tocar la opción ya elegida la deselecciona
            // (volver a cero); obligatorio: siempre queda una elegida.
            if current.contains(modificador.id) && !grupo.isRequired {
                current = []
            } else {
                current = [modificador.id]
            }
        } else {
            if current.contains(modificador.id) {
                current.remove(modificador.id)
            } else if current.count < grupo.maxSelecciones {
                current.insert(modificador.id)
            }
        }
        seleccion[grupo.id] = current
    }

    /// Faltan grupos obligatorios por completar su mínimo. Mientras carga
    /// (state != .ready) NO se puede agregar: `grupos` está vacío y `allSatisfy`
    /// sobre vacío daría `true`, dejando agregar sin los modificadores obligatorios.
    var puedeAgregar: Bool {
        guard case .ready = state else { return false }
        return grupos.allSatisfy { grupo in
            (seleccion[grupo.id]?.count ?? 0) >= grupo.minSelecciones
        }
    }

    /// Hay un grupo obligatorio cuyas opciones están TODAS agotadas (llega vacío
    /// tras filtrar is_available): nunca se podrá completar → no es pedible.
    var hayGrupoRequeridoSinOpciones: Bool {
        grupos.contains { $0.isRequired && $0.modificadores.isEmpty }
    }

    private var modificadoresSeleccionados: [Modificador] {
        grupos.flatMap { grupo in
            grupo.modificadores.filter { seleccion[grupo.id]?.contains($0.id) ?? false }
        }
    }

    var precioUnitario: Decimal {
        producto.precio + modificadoresSeleccionados.reduce(Decimal(0)) { $0 + $1.precioExtra }
    }

    var total: Decimal {
        precioUnitario * Decimal(cantidad)
    }

    func incrementar() { if cantidad < 99 { cantidad += 1 } }
    func decrementar() { if cantidad > 1 { cantidad -= 1 } }

    func buildSelection() -> ProductSelection {
        ProductSelection(
            producto: producto,
            cantidad: cantidad,
            modificadores: modificadoresSeleccionados,
            total: total
        )
    }
}
