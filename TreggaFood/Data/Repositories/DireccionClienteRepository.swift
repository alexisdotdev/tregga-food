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
        isDefault: Bool,
        lat: Double?,
        lng: Double?,
        calle: String?,
        codigoPostal: String?,
        colonia: String?,
        municipio: String?,
        estado: String?,
        instrucciones: String?,
        fotos: [String]
    ) async throws -> DireccionCliente
    @discardableResult
    func editar(
        id: UUID,
        label: String,
        address: String,
        referencias: String?
    ) async throws -> DireccionCliente
    /// Edición completa (desde el selector de mapa): coords, componentes,
    /// instrucciones y fotos. No toca `is_default`.
    @discardableResult
    func actualizar(
        id: UUID,
        label: String,
        address: String,
        referencias: String?,
        lat: Double?,
        lng: Double?,
        calle: String?,
        codigoPostal: String?,
        colonia: String?,
        municipio: String?,
        estado: String?,
        instrucciones: String?,
        fotos: [String]
    ) async throws -> DireccionCliente
    func eliminar(id: UUID) async throws
    /// Marca una dirección como principal y desmarca las demás del cliente.
    func hacerDefault(id: UUID, clienteId: UUID) async throws
}

public extension DireccionClienteRepository {
    /// Conveniencia: alta sin coordenadas (signup/cuenta). Delega en la versión
    /// completa con `nil` en geolocalización.
    @discardableResult
    func crear(
        clienteId: UUID,
        label: String,
        address: String,
        referencias: String?,
        isDefault: Bool
    ) async throws -> DireccionCliente {
        try await crear(
            clienteId: clienteId, label: label, address: address,
            referencias: referencias, isDefault: isDefault,
            lat: nil, lng: nil, calle: nil, codigoPostal: nil, colonia: nil, municipio: nil, estado: nil,
            instrucciones: nil, fotos: []
        )
    }
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
        let instrucciones: String?
        let fotos: [String]?

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
                calle: calle,
                instrucciones: instrucciones,
                fotos: fotos ?? []
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
        isDefault: Bool,
        lat: Double?,
        lng: Double?,
        calle: String?,
        codigoPostal: String?,
        colonia: String?,
        municipio: String?,
        estado: String?,
        instrucciones: String?,
        fotos: [String]
    ) async throws -> DireccionCliente {
        struct Insert: Encodable {
            let cliente_id: String
            let label: String
            let address: String
            let referencias: String?
            let is_default: Bool
            let lat: Double?
            let lng: Double?
            let calle: String?
            let codigo_postal: String?
            let colonia: String?
            let municipio: String?
            let estado: String?
            let instrucciones: String?
            let fotos: [String]
        }
        let dto: DireccionDTO = try await client.from("direcciones_cliente")
            .insert(Insert(
                cliente_id: clienteId.uuidString,
                label: label,
                address: address,
                referencias: referencias,
                is_default: isDefault,
                lat: lat,
                lng: lng,
                calle: calle,
                codigo_postal: codigoPostal,
                colonia: colonia,
                municipio: municipio,
                estado: estado,
                instrucciones: instrucciones,
                fotos: fotos
            ))
            .select()
            .single()
            .execute()
            .value
        return dto.toDomain()
    }

    @discardableResult
    public func editar(
        id: UUID,
        label: String,
        address: String,
        referencias: String?
    ) async throws -> DireccionCliente {
        struct Update: Encodable {
            let label: String
            let address: String
            let referencias: String?
        }
        let dto: DireccionDTO = try await client.from("direcciones_cliente")
            .update(Update(label: label, address: address, referencias: referencias))
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value
        return dto.toDomain()
    }

    @discardableResult
    public func actualizar(
        id: UUID,
        label: String,
        address: String,
        referencias: String?,
        lat: Double?,
        lng: Double?,
        calle: String?,
        codigoPostal: String?,
        colonia: String?,
        municipio: String?,
        estado: String?,
        instrucciones: String?,
        fotos: [String]
    ) async throws -> DireccionCliente {
        struct Update: Encodable {
            let label: String
            let address: String
            let referencias: String?
            let lat: Double?
            let lng: Double?
            let calle: String?
            let codigo_postal: String?
            let colonia: String?
            let municipio: String?
            let estado: String?
            let instrucciones: String?
            let fotos: [String]
        }
        let dto: DireccionDTO = try await client.from("direcciones_cliente")
            .update(Update(
                label: label,
                address: address,
                referencias: referencias,
                lat: lat,
                lng: lng,
                calle: calle,
                codigo_postal: codigoPostal,
                colonia: colonia,
                municipio: municipio,
                estado: estado,
                instrucciones: instrucciones,
                fotos: fotos
            ))
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value
        return dto.toDomain()
    }

    public func eliminar(id: UUID) async throws {
        try await client.from("direcciones_cliente")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    public func hacerDefault(id: UUID, clienteId: UUID) async throws {
        struct Flag: Encodable { let is_default: Bool }
        // Desmarca todas las del cliente, luego marca la elegida.
        try await client.from("direcciones_cliente")
            .update(Flag(is_default: false))
            .eq("cliente_id", value: clienteId.uuidString)
            .execute()
        try await client.from("direcciones_cliente")
            .update(Flag(is_default: true))
            .eq("id", value: id.uuidString)
            .execute()
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
        isDefault: Bool,
        lat: Double?,
        lng: Double?,
        calle: String?,
        codigoPostal: String?,
        colonia: String?,
        municipio: String?,
        estado: String?,
        instrucciones: String?,
        fotos: [String]
    ) async throws -> DireccionCliente {
        DireccionCliente(
            id: UUID(),
            clienteId: clienteId,
            label: label,
            address: address,
            lat: lat,
            lng: lng,
            referencias: referencias,
            isDefault: isDefault,
            codigoPostal: codigoPostal,
            estado: estado,
            municipio: municipio,
            colonia: colonia,
            calle: calle,
            instrucciones: instrucciones,
            fotos: fotos
        )
    }

    @discardableResult
    public func editar(
        id: UUID,
        label: String,
        address: String,
        referencias: String?
    ) async throws -> DireccionCliente {
        DireccionCliente(id: id, clienteId: UUID(), label: label, address: address, referencias: referencias)
    }

    @discardableResult
    public func actualizar(
        id: UUID,
        label: String,
        address: String,
        referencias: String?,
        lat: Double?,
        lng: Double?,
        calle: String?,
        codigoPostal: String?,
        colonia: String?,
        municipio: String?,
        estado: String?,
        instrucciones: String?,
        fotos: [String]
    ) async throws -> DireccionCliente {
        DireccionCliente(
            id: id, clienteId: UUID(), label: label, address: address,
            lat: lat, lng: lng, referencias: referencias,
            codigoPostal: codigoPostal, estado: estado, municipio: municipio,
            colonia: colonia, calle: calle, instrucciones: instrucciones, fotos: fotos
        )
    }

    public func eliminar(id: UUID) async throws {}

    public func hacerDefault(id: UUID, clienteId: UUID) async throws {}
}
