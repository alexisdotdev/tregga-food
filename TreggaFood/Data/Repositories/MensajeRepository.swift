import Foundation
import TreggaCore
import Supabase

/// Chat in-app entre cliente y repartidor (tabla `mensajes`).
public protocol MensajeRepository: Sendable {
    func fetch(pedidoId: UUID, miUserId: UUID?) async throws -> [Mensaje]
    @discardableResult
    func enviar(pedidoId: UUID, senderId: UUID, content: String) async throws -> Mensaje
}

// MARK: - Supabase

public final class SupabaseMensajeRepository: MensajeRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient = SupabaseClientShared.client) {
        self.client = client
    }

    struct MensajeDTO: Decodable {
        let id: UUID
        let sender_id: UUID?
        let sender_role: String?
        let content: String
        let created_at: Date

        func toDomain(miUserId: UUID?) -> Mensaje {
            let role = sender_role ?? ""
            let esMio = role == "cliente" || (miUserId != nil && sender_id == miUserId)
            return Mensaje(
                id: id,
                content: content,
                senderRole: role,
                fecha: created_at,
                esMio: esMio
            )
        }
    }

    public func fetch(pedidoId: UUID, miUserId: UUID?) async throws -> [Mensaje] {
        let dtos: [MensajeDTO] = try await client.from("mensajes")
            .select("id,sender_id,sender_role,content,created_at")
            .eq("pedido_id", value: pedidoId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
        return dtos.map { $0.toDomain(miUserId: miUserId) }
    }

    @discardableResult
    public func enviar(pedidoId: UUID, senderId: UUID, content: String) async throws -> Mensaje {
        struct Insert: Encodable {
            let pedido_id: String
            let sender_id: String
            let sender_role: String
            let content: String
        }
        let dto: MensajeDTO = try await client.from("mensajes")
            .insert(Insert(
                pedido_id: pedidoId.uuidString,
                sender_id: senderId.uuidString,
                sender_role: "cliente",
                content: content
            ))
            .select("id,sender_id,sender_role,content,created_at")
            .single()
            .execute()
            .value
        return dto.toDomain(miUserId: senderId)
    }
}

// MARK: - Mock

/// Mock con almacenamiento en memoria vía actor (evita NSLock en async).
public final class MockMensajeRepository: MensajeRepository {
    private actor Store {
        var mensajes: [Mensaje]
        init(_ seed: [Mensaje]) { self.mensajes = seed }
        func all() -> [Mensaje] { mensajes }
        func append(_ m: Mensaje) { mensajes.append(m) }
    }
    private let store: Store

    public init() {
        let ahora = Date()
        store = Store([
            Mensaje(id: UUID(), content: "¡Hola! 👋 Ya estoy recogiendo tu pedido en Carnitas Don Lupe.", senderRole: "repartidor", fecha: ahora.addingTimeInterval(-600), esMio: false),
            Mensaje(id: UUID(), content: "¡Gracias Miguel! Aquí te espero.", senderRole: "cliente", fecha: ahora.addingTimeInterval(-540), esMio: true),
            Mensaje(id: UUID(), content: "Listo, ya tengo todo. Voy en camino 🛵", senderRole: "repartidor", fecha: ahora.addingTimeInterval(-180), esMio: false),
        ])
    }

    public func fetch(pedidoId: UUID, miUserId: UUID?) async throws -> [Mensaje] {
        await store.all()
    }

    @discardableResult
    public func enviar(pedidoId: UUID, senderId: UUID, content: String) async throws -> Mensaje {
        let m = Mensaje(id: UUID(), content: content, senderRole: "cliente", fecha: Date(), esMio: true)
        await store.append(m)
        return m
    }
}
