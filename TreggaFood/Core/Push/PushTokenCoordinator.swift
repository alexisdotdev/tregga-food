import Foundation
import TreggaCore
import Supabase
import UserNotifications

/// Registra/desactiva el token de push del dispositivo en `device_tokens`.
public protocol DeviceTokenRepository: Sendable {
    func registerToken(userId: UUID, token: String) async throws
    func deactivateToken(token: String) async throws
}

public final class SupabaseDeviceTokenRepository: DeviceTokenRepository {
    private let client: SupabaseClient
    public init(client: SupabaseClient = SupabaseClientShared.client) { self.client = client }

    public func registerToken(userId: UUID, token: String) async throws {
        struct Row: Encodable {
            let user_id: String
            let token: String
            let platform: String
            let is_active: Bool
            let updated_at: String
        }
        let row = Row(
            user_id: userId.uuidString,
            token: token,
            platform: "ios",
            is_active: true,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        try await client.from("device_tokens").upsert(row, onConflict: "token").execute()
    }

    public func deactivateToken(token: String) async throws {
        try await client.from("device_tokens")
            .update(["is_active": false])
            .eq("token", value: token)
            .execute()
    }
}

public struct MockDeviceTokenRepository: DeviceTokenRepository {
    public init() {}
    public func registerToken(userId: UUID, token: String) async throws {}
    public func deactivateToken(token: String) async throws {}
}

/// Coordina el ciclo de vida del token FCM con la sesión del cliente.
/// El `AppDelegate` le entrega el token FCM cuando llega; al iniciar sesión se
/// registra en `device_tokens` y al cerrar sesión se desactiva. El push solo se
/// entrega en dispositivo físico con APNs configurado (cuenta de pago + .p8).
@MainActor
public final class PushTokenCoordinator {
    public static let shared = PushTokenCoordinator()

    public var repo: DeviceTokenRepository = SupabaseDeviceTokenRepository()
    private var currentUserId: UUID?
    private var lastToken: String?

    private init() {}

    public func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])
    }

    /// Llamado por el AppDelegate cuando Firebase entrega/renueva el token FCM.
    public func onTokenRefresh(_ token: String) async {
        lastToken = token
        guard let uid = currentUserId else { return }
        await register(uid: uid, token: token)
    }

    /// Llamado al confirmarse la sesión del cliente.
    public func onLogin(userId: UUID) async {
        currentUserId = userId
        await requestAuthorization()
        if let t = lastToken { await register(uid: userId, token: t) }
    }

    private func register(uid: UUID, token: String) async {
        do {
            try await repo.registerToken(userId: uid, token: token)
        } catch {
            print("[Push] No se pudo registrar el token: \(error)")
        }
    }

    /// Llamado al cerrar sesión.
    public func onLogout() async {
        if let t = lastToken { try? await repo.deactivateToken(token: t) }
        currentUserId = nil
    }
}
