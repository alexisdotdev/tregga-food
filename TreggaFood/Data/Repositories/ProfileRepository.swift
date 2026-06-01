import Foundation
import TreggaCore
import Supabase

/// Acceso a `profiles` (role='cliente') para la app de cliente (F6 — Cuenta).
public protocol ProfileRepository: Sendable {
    /// Perfil enlazado a una cuenta auth. Si no existe la fila aún, devuelve nil.
    func fetch(userId: UUID) async throws -> PerfilCliente?
    /// Actualiza los campos editables del perfil. Solo escribe lo provisto.
    @discardableResult
    func actualizar(
        userId: UUID,
        fullName: String?,
        apellidoPaterno: String?,
        apellidoMaterno: String?,
        email: String?,
        phone: String?,
        fechaNacimiento: Date?
    ) async throws -> PerfilCliente
}

// MARK: - Supabase

public final class SupabaseProfileRepository: ProfileRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient = SupabaseClientShared.client) {
        self.client = client
    }

    struct ProfileDTO: Decodable {
        let id: UUID
        let full_name: String?
        let apellido_paterno: String?
        let apellido_materno: String?
        let email: String?
        let phone: String?
        let avatar_url: String?
        let fecha_nacimiento: String?
        let codigo_postal: String?
        let estado: String?
        let municipio: String?
        let colonia: String?
        let calle: String?
        let curp: String?

        func toDomain() -> PerfilCliente {
            PerfilCliente(
                id: id,
                fullName: full_name ?? "",
                apellidoPaterno: apellido_paterno ?? "",
                apellidoMaterno: apellido_materno ?? "",
                email: email,
                phone: phone,
                avatarUrl: avatar_url,
                fechaNacimiento: fecha_nacimiento.flatMap { Self.dateFormatter.date(from: $0) },
                codigoPostal: codigo_postal,
                estado: estado,
                municipio: municipio,
                colonia: colonia,
                calle: calle,
                curp: curp
            )
        }

        static let dateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.calendar = Calendar(identifier: .gregorian)
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(identifier: "UTC")
            f.dateFormat = "yyyy-MM-dd"
            return f
        }()
    }

    public func fetch(userId: UUID) async throws -> PerfilCliente? {
        let dtos: [ProfileDTO] = try await client.from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        return dtos.first?.toDomain()
    }

    @discardableResult
    public func actualizar(
        userId: UUID,
        fullName: String?,
        apellidoPaterno: String?,
        apellidoMaterno: String?,
        email: String?,
        phone: String?,
        fechaNacimiento: Date?
    ) async throws -> PerfilCliente {
        struct Update: Encodable {
            var full_name: String?
            var apellido_paterno: String?
            var apellido_materno: String?
            var email: String?
            var phone: String?
            var fecha_nacimiento: String?
        }
        let update = Update(
            full_name: fullName,
            apellido_paterno: apellidoPaterno,
            apellido_materno: apellidoMaterno,
            email: email,
            phone: phone,
            fecha_nacimiento: fechaNacimiento.map { ProfileDTO.dateFormatter.string(from: $0) }
        )
        let dto: ProfileDTO = try await client.from("profiles")
            .update(update)
            .eq("id", value: userId.uuidString)
            .select()
            .single()
            .execute()
            .value
        return dto.toDomain()
    }
}

// MARK: - Mock

public final class MockProfileRepository: ProfileRepository {
    public init() {}

    public func fetch(userId: UUID) async throws -> PerfilCliente? {
        PerfilCliente(
            id: userId,
            fullName: "Juan Carlos",
            apellidoPaterno: "Ramírez",
            apellidoMaterno: "Vega",
            email: "juan.ramirez@gmail.com",
            phone: "+524431234567",
            municipio: "Zinapécuaro",
            colonia: "Centro"
        )
    }

    @discardableResult
    public func actualizar(
        userId: UUID,
        fullName: String?,
        apellidoPaterno: String?,
        apellidoMaterno: String?,
        email: String?,
        phone: String?,
        fechaNacimiento: Date?
    ) async throws -> PerfilCliente {
        PerfilCliente(
            id: userId,
            fullName: fullName ?? "Juan Carlos",
            apellidoPaterno: apellidoPaterno ?? "Ramírez",
            apellidoMaterno: apellidoMaterno ?? "Vega",
            email: email ?? "juan.ramirez@gmail.com",
            phone: phone ?? "+524431234567",
            fechaNacimiento: fechaNacimiento
        )
    }
}
