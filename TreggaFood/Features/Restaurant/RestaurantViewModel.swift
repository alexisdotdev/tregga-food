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
    private let negocioId: UUID
    private let repository: CatalogRepository

    init(negocioId: UUID, repository: CatalogRepository) {
        self.negocioId = negocioId
        self.repository = repository
    }

    func load() async {
        state = .loading
        do {
            let menu = try await repository.fetchMenu(negocioId: negocioId)
            state = menu.isEmpty ? .empty : .loaded(menu)
        } catch {
            state = .error("No pudimos cargar el menú. Intenta de nuevo.")
        }
    }
}
