import Foundation
import Observation

@MainActor
@Observable
final class TrackingViewModel {
    enum Phase: Equatable {
        case loading
        case loaded
        case error(String)
    }

    private(set) var phase: Phase = .loading
    private(set) var pedido: PedidoTracking?
    private(set) var repartidorCoord: TrackCoord?

    /// Se activa una vez cuando el pedido pasa a completado, para navegar a éxito.
    var didComplete: Bool = false

    private let pedidoId: UUID
    private let repo: TrackingRepository
    private var pollingTask: Task<Void, Never>?

    init(pedidoId: UUID, repo: TrackingRepository) {
        self.pedidoId = pedidoId
        self.repo = repo
    }

    func start() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            guard let self else { return }
            await self.refresh(initial: true)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_500_000_000)
                if Task.isCancelled { break }
                await self.refresh(initial: false)
                if self.pedido?.status.isTerminal == true { break }
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func reintentar() {
        phase = .loading
        stop()
        start()
    }

    private func refresh(initial: Bool) async {
        do {
            let p = try await repo.fetchPedido(id: pedidoId)
            pedido = p
            if let repId = p.repartidorId {
                if let ubic = try? await repo.fetchUbicacionRepartidor(repartidorId: repId) {
                    repartidorCoord = ubic.coord
                }
            }
            phase = .loaded
            if p.status.isCompleted && !didComplete {
                didComplete = true
            }
        } catch {
            if initial {
                phase = .error("No pudimos cargar tu pedido. Revisa tu conexión.")
            }
        }
    }
}
