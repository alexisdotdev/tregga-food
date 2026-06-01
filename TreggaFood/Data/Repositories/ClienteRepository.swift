import Foundation
import TreggaCore

/// Acceso a la entidad `clientes` (+ enlace con `profiles`) para la app de cliente.
public protocol ClienteRepository: Sendable {
    /// Cliente enlazado a una cuenta auth, si existe.
    func fetchByUserId(_ userId: UUID) async throws -> Cliente?
    /// Cliente por teléfono (para reconciliar historial WhatsApp previo).
    func fetchByPhone(_ phone: String) async throws -> Cliente?
    /// Crea o enlaza el cliente a la cuenta auth y asegura el `profiles(role='cliente')`.
    /// Idempotente: si ya existe un cliente con ese teléfono, le asigna `user_id`.
    @discardableResult
    func linkOrCreate(
        userId: UUID,
        phone: String,
        fullName: String,
        email: String?
    ) async throws -> Cliente
}

// MARK: - Mock

public final class MockClienteRepository: ClienteRepository {
    public init() {}
    public func fetchByUserId(_ userId: UUID) async throws -> Cliente? {
        Cliente(id: UUID(), userId: userId, phone: "+525550000000", fullName: "Cliente Demo")
    }
    public func fetchByPhone(_ phone: String) async throws -> Cliente? { nil }
    @discardableResult
    public func linkOrCreate(userId: UUID, phone: String, fullName: String, email: String?) async throws -> Cliente {
        Cliente(id: UUID(), userId: userId, phone: phone, fullName: fullName, email: email)
    }
}
