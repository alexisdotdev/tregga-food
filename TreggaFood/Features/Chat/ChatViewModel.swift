import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {
    private(set) var mensajes: [Mensaje] = []
    private(set) var cargando = true
    private(set) var errorMsg: String?
    var borrador: String = ""

    let quickReplies = ["Ya voy llegando", "¿Cuánto te falta?", "Toca el portón", "Gracias 🙌"]

    private let pedidoId: UUID
    private let senderId: UUID?
    private let repo: MensajeRepository
    private var pollingTask: Task<Void, Never>?

    init(pedidoId: UUID, senderId: UUID?, repo: MensajeRepository) {
        self.pedidoId = pedidoId
        self.senderId = senderId
        self.repo = repo
    }

    var puedeEnviar: Bool {
        !borrador.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func start() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            guard let self else { return }
            await self.cargar()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if Task.isCancelled { break }
                await self.cargar(silencioso: true)
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func cargar(silencioso: Bool = false) async {
        do {
            mensajes = try await repo.fetch(pedidoId: pedidoId, miUserId: senderId)
            errorMsg = nil
        } catch {
            if !silencioso { errorMsg = "No pudimos cargar el chat." }
        }
        cargando = false
    }

    func enviar() async {
        let texto = borrador.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !texto.isEmpty, let senderId else { return }
        borrador = ""
        do {
            let m = try await repo.enviar(pedidoId: pedidoId, senderId: senderId, content: texto)
            if !mensajes.contains(where: { $0.id == m.id }) {
                mensajes.append(m)
            }
        } catch {
            borrador = texto
            errorMsg = "No se pudo enviar tu mensaje."
        }
    }

    func enviarRapido(_ texto: String) async {
        borrador = texto
        await enviar()
    }
}
