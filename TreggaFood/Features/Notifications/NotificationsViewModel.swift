import Foundation
import Observation
import TreggaCore

/// ViewModel para Notificaciones e Inbox. Carga las notificaciones reales del
/// usuario y permite marcar leídas. El Inbox reutiliza la misma fuente filtrando
/// por categorías de "avisos" (sistema/promos/ofertas).
@MainActor
@Observable
final class NotificationsViewModel {
    enum State: Equatable {
        case loading
        case loaded([Notificacion])
        case empty
        case error(String)
    }

    private(set) var state: State = .loading

    private let userId: UUID?
    private let repo: NotificacionRepository

    init(userId: UUID?, repo: NotificacionRepository) {
        self.userId = userId
        self.repo = repo
    }

    var noLeidas: Int {
        if case let .loaded(items) = state { return items.filter { !$0.read }.count }
        return 0
    }

    func cargar() async {
        guard let userId else { state = .empty; return }
        if case .loaded = state {} else { state = .loading }
        do {
            let items = try await repo.fetch(userId: userId)
            state = items.isEmpty ? .empty : .loaded(items)
        } catch {
            state = .error("No pudimos cargar tus notificaciones. Revisa tu conexión.")
        }
    }

    func marcarLeida(_ id: UUID) async {
        guard case var .loaded(items) = state else { return }
        guard let i = items.firstIndex(where: { $0.id == id }), !items[i].read else { return }
        items[i].read = true
        state = .loaded(items)
        try? await repo.marcarLeida(id: id)
    }

    func marcarTodasLeidas() async {
        guard let userId, case var .loaded(items) = state else { return }
        for i in items.indices { items[i].read = true }
        state = .loaded(items)
        try? await repo.marcarTodasLeidas(userId: userId)
    }

    func eliminar(_ id: UUID) async {
        guard case var .loaded(items) = state else { return }
        items.removeAll { $0.id == id }
        state = items.isEmpty ? .empty : .loaded(items)
        try? await repo.eliminar(id: id)
    }
}
