import Foundation
import Observation
import TreggaCore

@MainActor
@Observable
final class RestaurantViewModel {
    enum State: Equatable {
        case loading
        case loaded([MenuSection])
        case empty
        case error(String)
    }

    private(set) var state: State = .loading
    /// Abierto/cerrado derivado de los horarios; nil si el negocio no los configuró.
    private(set) var estadoApertura: EstadoApertura?
    /// `acepta_pedidos` fresco del server (el Home se cachea); nil hasta cargar.
    private(set) var aceptaPedidosActual: Bool?
    /// Horarios de las franjas del negocio (defaults si no las configuró).
    private(set) var franjasHorario: FranjasHorario = .porDefecto
    private let negocioId: UUID
    private let repository: CatalogRepository
    private var observeTask: Task<Void, Never>?

    init(negocioId: UUID, repository: CatalogRepository) {
        self.negocioId = negocioId
        self.repository = repository
    }

    /// Escucha en vivo si ESTE negocio pausa/activa mientras se ve el detalle.
    func observarCambios() {
        guard observeTask == nil else { return }
        observeTask = Task { [weak self] in
            guard let self else { return }
            for await _ in repository.observeNegociosCambios(negocioId: negocioId) {
                if Task.isCancelled { break }
                aceptaPedidosActual = (try? await repository.fetchAceptaPedidos(negocioId: negocioId))
            }
        }
    }

    func detenerObservacion() {
        observeTask?.cancel()
        observeTask = nil
    }

    func load() async {
        state = .loading
        async let horariosTask = (try? await repository.fetchHorarios(negocioId: negocioId)) ?? []
        async let aceptaTask = (try? await repository.fetchAceptaPedidos(negocioId: negocioId))
        async let franjasTask = (try? await repository.fetchFranjasHorario(negocioId: negocioId)) ?? .porDefecto
        do {
            let menu = try await repository.fetchMenu(negocioId: negocioId)
            state = menu.isEmpty ? .empty : .loaded(menu)
        } catch {
            state = .error("No pudimos cargar el menú. Intenta de nuevo.")
        }
        estadoApertura = EstadoApertura.calcular(await horariosTask)
        aceptaPedidosActual = await aceptaTask
        franjasHorario = await franjasTask
    }

    /// ¿El platillo se sirve a esta hora? (franjas vacías = todo el día).
    func disponibleAhora(_ producto: Producto) -> Bool {
        DisponibilidadMenu.disponibleAhora(franjas: producto.franjas, horario: franjasHorario)
    }

    /// Texto "Disponible en la mañana/tarde/noche" si el platillo está fuera de su
    /// franja ahora; nil si se puede pedir.
    func textoFueraDeFranja(_ producto: Producto) -> String? {
        disponibleAhora(producto) ? nil : DisponibilidadMenu.textoNoDisponible(franjas: producto.franjas)
    }
}
