import Foundation
import Observation
import TreggaCore

@MainActor
@Observable
final class MyOrdersViewModel {
    enum Phase: Equatable {
        case cargando
        case cargado
        case vacio
        case error(String)
    }

    private(set) var phase: Phase = .cargando
    private(set) var enCurso: [PedidoResumen] = []
    private(set) var anteriores: [PedidoResumen] = []

    private let clienteRepository: ClienteRepository
    private let pedidoRepository: PedidoRepository
    private let userId: UUID?
    private var clienteId: UUID?

    init(
        clienteRepository: ClienteRepository,
        pedidoRepository: PedidoRepository,
        userId: UUID?
    ) {
        self.clienteRepository = clienteRepository
        self.pedidoRepository = pedidoRepository
        self.userId = userId
    }

    func cargar() async {
        phase = .cargando
        do {
            if clienteId == nil, let userId {
                clienteId = try await clienteRepository.fetchByUserId(userId)?.id
            }
            guard let clienteId else { phase = .vacio; return }
            let historial = try await pedidoRepository.fetchHistorial(clienteId: clienteId)
            enCurso = historial.filter { $0.enCurso }
            anteriores = historial.filter { !$0.enCurso }
            phase = historial.isEmpty ? .vacio : .cargado
        } catch {
            phase = .error("No pudimos cargar tus pedidos. Intenta de nuevo.")
        }
    }
}
