import Foundation
import TreggaCore
import Supabase

/// Operaciones sobre la cuenta del usuario autenticado (F6 — Cuenta).
/// Hoy: eliminación de cuenta vía RPC `delete_my_account` (borra perfil,
/// cliente y datos asociados; el borrado de `auth.users` lo hace el RPC con
/// privilegios de servicio — NO se toca a mano).
public protocol AccountRepository: Sendable {
    func eliminarCuenta() async throws
    /// Solicita el export de datos del usuario (envío de ZIP a su correo).
    /// Hook: hoy solo registra la solicitud; el procesamiento es backend.
    func solicitarDescargaDatos(userId: UUID) async throws
}

// MARK: - Supabase

public final class SupabaseAccountRepository: AccountRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient = SupabaseClientShared.client) {
        self.client = client
    }

    public func eliminarCuenta() async throws {
        try await client.rpc("delete_my_account").execute()
    }

    public func solicitarDescargaDatos(userId: UUID) async throws {
        struct Insert: Encodable {
            let user_id: String
        }
        try await client.from("solicitudes_export")
            .insert(Insert(user_id: userId.uuidString))
            .execute()
    }
}

// MARK: - Mock

public final class MockAccountRepository: AccountRepository {
    public init() {}
    public func eliminarCuenta() async throws {}
    public func solicitarDescargaDatos(userId: UUID) async throws {}
}
