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

    init(repository: CatalogRepository) {
        self.repository = repository
    }

    func load() async {
        state = .loading
        do {
            let negocios = try await repository.fetchNegociosDisponibles()
            state = negocios.isEmpty ? .empty : .loaded(negocios)
        } catch {
            state = .error("No pudimos cargar los negocios. Revisa tu conexión e intenta de nuevo.")
        }
    }
}
