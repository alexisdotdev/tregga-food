import Foundation
import TreggaCore
import Supabase

/// Acceso a `notificaciones` (1:N con `auth.users`) para la app de cliente.
/// Cubre fetch, marcar una leída y marcar todas leídas. Filtra por usuario.
public protocol NotificacionRepository: Sendable {
    func fetch(userId: UUID) async throws -> [Notificacion]
    func marcarLeida(id: UUID) async throws
    func marcarTodasLeidas(userId: UUID) async throws
    func eliminar(id: UUID) async throws
}

// MARK: - Supabase

public final class SupabaseNotificacionRepository: NotificacionRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient = SupabaseClientShared.client) {
        self.client = client
    }

    struct NotificacionDTO: Codable {
        let id: UUID
        let title: String
        let description: String?
        let type: String
        let category: String
        let read: Bool?
        let created_at: Date?
        let reference_type: String?

        func toDomain() -> Notificacion {
            Notificacion(
                id: id,
                title: title,
                body: description,
                category: Notificacion.Categoria(rawValue: category) ?? .sistema,
                kind: Notificacion.Tipo(rawValue: type) ?? .info,
                read: read ?? false,
                createdAt: created_at,
                referenceType: reference_type
            )
        }
    }

    public func fetch(userId: UUID) async throws -> [Notificacion] {
        // Solo notificaciones dirigidas al rol cliente: una cuenta multi-rol
        // (p. ej. un super_admin que también usa Food) recibía mezcladas en el
        // mismo `user_id` las de negocio/repartidor/admin. El filtro por audiencia
        // las separa en origen.
        let dtos: [NotificacionDTO] = try await client.from("notificaciones")
            .select("id,title,description,type,category,read,created_at,reference_type")
            .eq("user_id", value: userId.uuidString)
            .eq("audience", value: "cliente")
            .order("created_at", ascending: false)
            .limit(100)
            .execute()
            .value
        return dtos.map { $0.toDomain() }
    }

    public func marcarLeida(id: UUID) async throws {
        try await client.from("notificaciones")
            .update(["read": true])
            .eq("id", value: id.uuidString)
            .execute()
    }

    public func marcarTodasLeidas(userId: UUID) async throws {
        try await client.from("notificaciones")
            .update(["read": true])
            .eq("user_id", value: userId.uuidString)
            .eq("audience", value: "cliente")
            .eq("read", value: false)
            .execute()
    }

    public func eliminar(id: UUID) async throws {
        try await client.from("notificaciones")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

// MARK: - Mock

/// Mock con almacenamiento en memoria vía actor (evita NSLock en async).
public final class MockNotificacionRepository: NotificacionRepository {
    private actor Store {
        var items: [Notificacion]

        init(_ items: [Notificacion]) { self.items = items }

        func all() -> [Notificacion] { items }

        func marcar(_ id: UUID) {
            if let i = items.firstIndex(where: { $0.id == id }) { items[i].read = true }
        }

        func marcarTodas() {
            for i in items.indices { items[i].read = true }
        }

        func eliminar(_ id: UUID) {
            items.removeAll { $0.id == id }
        }
    }

    private let store: Store

    public init() {
        let now = Date()
        func ago(_ h: Int) -> Date { Calendar.current.date(byAdding: .hour, value: -h, to: now) ?? now }
        self.store = Store([
            Notificacion(id: UUID(), title: "Tu pedido está en camino",
                         body: "Carnitas Don Lupe · llega en ~15 min.",
                         category: .sistema, kind: .info, read: false, createdAt: ago(1)),
            Notificacion(id: UUID(), title: "Envío gratis esta semana",
                         body: "Pide en Mamá Rosa o El Charal y no pagas envío.",
                         category: .promos, kind: .info, read: false, createdAt: ago(3)),
            Notificacion(id: UUID(), title: "Pago confirmado",
                         body: "Recibimos tu pago en efectivo del pedido #DEMO-A12.",
                         category: .pagos, kind: .info, read: true, createdAt: ago(26)),
            Notificacion(id: UUID(), title: "2x1 en postres hoy",
                         body: "Aprovecha el 2x1 en negocios participantes hasta las 10pm.",
                         category: .ofertas, kind: .info, read: true, createdAt: ago(50)),
            Notificacion(id: UUID(), title: "Actualización de la app",
                         body: "Mejoramos el tracking en tiempo real y los pagos en efectivo.",
                         category: .sistema, kind: .system, read: true, createdAt: ago(74)),
        ])
    }

    public func fetch(userId: UUID) async throws -> [Notificacion] {
        await store.all()
    }

    public func marcarLeida(id: UUID) async throws {
        await store.marcar(id)
    }

    public func marcarTodasLeidas(userId: UUID) async throws {
        await store.marcarTodas()
    }

    public func eliminar(id: UUID) async throws {
        await store.eliminar(id)
    }
}
