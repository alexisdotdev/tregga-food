import Foundation
import Observation

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
        do {
            let menu = try await repository.fetchMenu(negocioId: negocioId)
            state = menu.isEmpty ? .empty : .loaded(menu)
        } catch {
            state = .error("No pudimos cargar el menú. Intenta de nuevo.")
        }
        estadoApertura = EstadoApertura.calcular(await horariosTask)
        aceptaPedidosActual = await aceptaTask
    }
}
