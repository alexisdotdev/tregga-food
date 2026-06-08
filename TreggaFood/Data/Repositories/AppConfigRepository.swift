import Foundation
import TreggaCore
import Supabase

/// Configuración remota mínima (tabla `app_config`, una fila) para gates de
/// arranque: mantenimiento y versión mínima soportada en iOS.
public struct AppConfig: Sendable, Equatable {
    public let minVersionIOS: String
    public let maintenance: Bool
    public let maintenanceMessage: String?
    public let iosStoreURL: String?
}

public protocol AppConfigRepository: Sendable {
    func fetch() async throws -> AppConfig
}

// MARK: - Supabase

public final class SupabaseAppConfigRepository: AppConfigRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient = SupabaseClientShared.client) {
        self.client = client
    }

    public func fetch() async throws -> AppConfig {
        struct DTO: Decodable {
            let min_version_ios: String
            let maintenance: Bool
            let maintenance_message: String?
            let ios_store_url: String?
        }
        let dto: DTO = try await client.from("app_config")
            .select("min_version_ios, maintenance, maintenance_message, ios_store_url")
            .eq("id", value: 1)
            .single()
            .execute()
            .value
        return AppConfig(
            minVersionIOS: dto.min_version_ios,
            maintenance: dto.maintenance,
            maintenanceMessage: dto.maintenance_message,
            iosStoreURL: dto.ios_store_url
        )
    }
}

// MARK: - Mock

/// Config "dormida" (sin mantenimiento, versión mínima muy baja) para que en modo
/// Mock/preview nunca bloquee el arranque.
public struct MockAppConfigRepository: AppConfigRepository {
    public init() {}
    public func fetch() async throws -> AppConfig {
        AppConfig(minVersionIOS: "0.0.0", maintenance: false, maintenanceMessage: nil, iosStoreURL: nil)
    }
}
