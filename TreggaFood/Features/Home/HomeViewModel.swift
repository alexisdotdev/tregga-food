import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    enum State: Equatable {
        case loading
        case loaded([Negocio])
        case empty
        case error(String)
    }

    private(set) var state: State = .loading
    private let repository: CatalogRepository
    private var observeTask: Task<Void, Never>?

    init(repository: CatalogRepository) {
        self.repository = repository
    }

    func load() async {
        // Solo mostramos el spinner en la primera carga; en recargas (realtime,
        // foreground) mantenemos la lista para no parpadear.
        if case .loaded = state {} else { state = .loading }
        do {
            let negocios = try await repository.fetchNegociosDisponibles()
            state = negocios.isEmpty ? .empty : .loaded(negocios)
        } catch {
            // En recarga no pisamos la lista existente con un error.
            if case .loaded = state {} else {
                state = .error("No pudimos cargar los negocios. Revisa tu conexión e intenta de nuevo.")
            }
        }
    }

    /// Escucha cambios de negocios en tiempo real (pausa/activación/status) y
    /// recarga el listado solo, sin pull-to-refresh. Idempotente.
    func observarCambios() {
        guard observeTask == nil else { return }
        observeTask = Task { [weak self] in
            guard let self else { return }
            for await _ in repository.observeNegociosCambios() {
                if Task.isCancelled { break }
                // Coalesce ráfagas de eventos antes de recargar.
                try? await Task.sleep(for: .milliseconds(300))
                await self.load()
            }
        }
    }

    func detenerObservacion() {
        observeTask?.cancel()
        observeTask = nil
    }
}
