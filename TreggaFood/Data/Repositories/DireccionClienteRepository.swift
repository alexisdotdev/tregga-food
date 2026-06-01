import Foundation
import TreggaCore
import Supabase

/// Acceso a `direcciones_cliente` para la app de cliente (F3).
public protocol DireccionClienteRepository: Sendable {
    func fetchDelCliente(clienteId: UUID) async throws -> [DireccionCliente]
    @discardableResult
    func crear(
        clienteId: UUID,
        label: String,
        address: String,
        referencias: String?,
        isDefault: Bool
    ) async throws -> DireccionCliente
}

// MARK: - Supabase

public final class SupabaseDireccionClienteRepository: DireccionClienteRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient = SupabaseClientShared.client) {
        self.client = client
    }

    struct DireccionDTO: Codable {
        let id: UUID
        let cliente_id: UUID
        let label: String?
        let address: String
        let lat: Double?
        let lng: Double?
        let referencias: String?
        let is_default: Bool?
        let codigo_postal: String?
        let estado: String?
        let municipio: String?
        let colonia: String?
        let calle: String?

        func toDomain() -> DireccionCliente {
            DireccionCliente(
                id: id,
                clienteId: cliente_id,
                label: label ?? "Casa",
                address: address,
                lat: lat,
                lng: lng,
                referencias: referencias,
                isDefault: is_default ?? false,
                codigoPostal: codigo_postal,
                estado: estado,
                municipio: municipio,
                colonia: colonia,
                calle: calle
            )
        }
    }

    public func fetchDelCliente(clienteId: UUID) async throws -> [DireccionCliente] {
        let dtos: [DireccionDTO] = try await client.from("direcciones_cliente")
            .select()
            .eq("cliente_id", value: clienteId.uuidString)
            .order("is_default", ascending: false)
            .execute()
            .value
        return dtos.map { $0.toDomain() }
    }

    @discardableResult
    public func crear(
        clienteId: UUID,
        label: String,
        address: String,
        referencias: String?,
        isDefault: Bool
    ) async throws -> DireccionCliente {
        struct Insert: Encodable {
            let cliente_id: String
            let label: String
            let address: String
            let referencias: String?
            let is_default: Bool
        }
        let dto: DireccionDTO = try await client.from("direcciones_cliente")
            .insert(Insert(
                cliente_id: clienteId.uuidString,
                label: label,
                address: address,
                referencias: referencias,
                is_default: isDefault
            ))
            .select()
            .single()
            .execute()
            .value
        return dto.toDomain()
    }
}

// MARK: - Mock

public final class MockDireccionClienteRepository: DireccionClienteRepository {
    public init() {}

    public func fetchDelCliente(clienteId: UUID) async throws -> [DireccionCliente] {
        [
            DireccionCliente(
                id: UUID(),
                clienteId: clienteId,
                label: "Casa",
                address: "Av. Hidalgo 142, Centro",
                referencias: "Casa azul, frente al jardín",
                isDefault: true,
                municipio: "Zinapécuaro",
                colonia: "Centro"
            )
        ]
    }

    @discardableResult
    public func crear(
        clienteId: UUID,
        label: String,
        address: String,
        referencias: String?,
        isDefault: Bool
    ) async throws -> DireccionCliente {
        DireccionCliente(
            id: UUID(),
            clienteId: clienteId,
            label: label,
            address: address,
            referencias: referencias,
            isDefault: isDefault
        )
    }
}
