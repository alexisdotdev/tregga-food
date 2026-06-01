import Foundation
import TreggaCore
import Supabase

public final class SupabaseClienteRepository: ClienteRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient = SupabaseClientShared.client) {
        self.client = client
    }

    struct ClienteDTO: Decodable {
        let id: UUID
        let user_id: UUID?
        let phone: String?
        let full_name: String?
        let apellido_paterno: String?
        let apellido_materno: String?
        let email: String?
        let total_orders: Int?
        let status: String?

        func toDomain() -> Cliente {
            Cliente(
                id: id,
                userId: user_id,
                phone: phone ?? "",
                fullName: full_name ?? "",
                apellidoPaterno: apellido_paterno ?? "",
                apellidoMaterno: apellido_materno ?? "",
                email: email,
                totalOrders: total_orders ?? 0,
                status: status ?? "active"
            )
        }
    }

    public func fetchByUserId(_ userId: UUID) async throws -> Cliente? {
        let dtos: [ClienteDTO] = try await client.from("clientes")
            .select()
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        return dtos.first?.toDomain()
    }

    public func fetchByPhone(_ phone: String) async throws -> Cliente? {
        let dtos: [ClienteDTO] = try await client.from("clientes")
            .select()
            .eq("phone", value: phone)
            .limit(1)
            .execute()
            .value
        return dtos.first?.toDomain()
    }

    @discardableResult
    public func linkOrCreate(
        userId: UUID,
        phone: String,
        fullName: String,
        email: String?
    ) async throws -> Cliente {
        struct Params: Encodable {
            let p_user_id: String
            let p_phone: String
            let p_full_name: String
            let p_email: String?
        }
        let dto: ClienteDTO = try await client
            .rpc("vincular_cliente", params: Params(
                p_user_id: userId.uuidString,
                p_phone: phone,
                p_full_name: fullName,
                p_email: email
            ))
            .execute()
            .value
        return dto.toDomain()
    }
}
