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
    private let clienteRepo: ClienteRepository
    private let userId: UUID?

    init(
        pedido: PedidoTracking,
        clienteId: UUID?,
        repo: CalificacionRepository,
        clienteRepo: ClienteRepository,
        userId: UUID?
    ) {
        self.pedido = pedido
        self.clienteId = clienteId
        self.repo = repo
        self.clienteRepo = clienteRepo
        self.userId = userId
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
        // La tabla exige rating 1–5, cliente y repartidor no nulos. Validamos antes
        // para dar un mensaje claro en vez de un fallo genérico del backend.
        guard (1...5).contains(rating) else {
            phase = .error("Elige cuántas estrellas antes de enviar.")
            return
        }
        // Si clienteId llegó nil (timing: sesión no lista al crear el VM), intentamos
        // resolverlo ahora con el userId de sesión antes de bloquear con error.
        var resolvedClienteId = clienteId
        if resolvedClienteId == nil, let uid = userId {
            resolvedClienteId = try? await clienteRepo.fetchByUserId(uid)?.id
        }
        guard resolvedClienteId != nil else {
            phase = .error("No pudimos identificar tu cuenta. Reinicia sesión e intenta de nuevo.")
            return
        }
        guard pedido.repartidorId != nil else {
            phase = .error("Este pedido no tiene repartidor asignado, no se puede calificar.")
            return
        }
        phase = .enviando
        do {
            try await repo.calificar(
                pedidoId: pedido.id,
                clienteId: resolvedClienteId,
                repartidorId: pedido.repartidorId,
                negocioId: pedido.negocioId,
                rating: rating,
                comment: comentario.trimmingCharacters(in: .whitespacesAndNewlines),
                tags: Array(tagsSeleccionados)
            )
            phase = .enviado
        } catch {
            phase = .error("No pudimos enviar tu calificación: \(error.localizedDescription)")
        }
    }
}
