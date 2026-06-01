import Foundation
import Observation

@MainActor
@Observable
final class RatingViewModel {
    enum Phase: Equatable {
        case idle
        case enviando
        case enviado
        case error(String)
    }

    private(set) var phase: Phase = .idle
    var rating: Int = 5
    var comentario: String = ""
    private(set) var tagsSeleccionados: Set<String> = []

    let tagsDisponibles = ["Rapidísimo", "Súper amable", "Cuidó la comida", "Buena comunicación"]

    private let pedido: PedidoTracking
    private let clienteId: UUID?
    private let repo: CalificacionRepository

    init(pedido: PedidoTracking, clienteId: UUID?, repo: CalificacionRepository) {
        self.pedido = pedido
        self.clienteId = clienteId
        self.repo = repo
    }

    var repartidorName: String { pedido.repartidorName ?? "tu repartidor" }
    var negocioName: String { pedido.negocioName ?? "el negocio" }

    func toggleTag(_ tag: String) {
        if tagsSeleccionados.contains(tag) { tagsSeleccionados.remove(tag) }
        else { tagsSeleccionados.insert(tag) }
    }

    func isTag(_ tag: String) -> Bool { tagsSeleccionados.contains(tag) }

    func enviar() async {
        guard phase != .enviando else { return }
        phase = .enviando
        do {
            try await repo.calificar(
                pedidoId: pedido.id,
                clienteId: clienteId,
                repartidorId: pedido.repartidorId,
                rating: rating,
                comment: comentario.trimmingCharacters(in: .whitespacesAndNewlines),
                tags: Array(tagsSeleccionados)
            )
            phase = .enviado
        } catch {
            phase = .error("No pudimos enviar tu calificación. Intenta de nuevo.")
        }
    }
}
