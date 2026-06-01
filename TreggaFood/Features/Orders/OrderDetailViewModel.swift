import Foundation
import Observation
import TreggaCore

@MainActor
@Observable
final class OrderDetailViewModel {
    enum Phase: Equatable {
        case cargando
        case cargado(PedidoDetalle)
        case error(String)
    }

    private(set) var phase: Phase = .cargando

    private let pedidoId: UUID
    private let pedidoRepository: PedidoRepository

    init(pedidoId: UUID, pedidoRepository: PedidoRepository) {
        self.pedidoId = pedidoId
        self.pedidoRepository = pedidoRepository
    }

    var detalle: PedidoDetalle? {
        if case .cargado(let d) = phase { return d }
        return nil
    }

    func cargar() async {
        phase = .cargando
        do {
            let detalle = try await pedidoRepository.fetchDetalle(pedidoId: pedidoId)
            phase = .cargado(detalle)
        } catch {
            phase = .error("No pudimos cargar este pedido. Intenta de nuevo.")
        }
    }
}
